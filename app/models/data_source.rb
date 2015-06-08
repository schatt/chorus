class DataSource < ActiveRecord::Base
  include SoftDelete
  include TaggableBehavior
  include Notable
  include CommonDataSourceBehavior

  attr_accessor :db_username, :db_password
  attr_accessible :name, :description, :host, :port, :ssl, :db_name, :db_username, :db_password, :is_hawq, :as => [:default, :create]
  attr_accessible :shared, :as => :create

  # Must happen before accounts are destroyed
  before_destroy :cancel_imports

  belongs_to :owner, :class_name => 'User'
  has_many :accounts, :class_name => 'DataSourceAccount', :inverse_of => :data_source, :foreign_key => 'data_source_id', :dependent => :destroy
  has_one :owner_account, :class_name => 'DataSourceAccount', :foreign_key => 'data_source_id', :inverse_of => :data_source, :conditions => proc { {:owner_id => owner_id} }

  has_many :activities, :as => :entity
  has_many :events, :through => :activities

  before_validation :build_data_source_account_for_owner, :on => :create

  validates_associated :owner_account, :if => :validate_owner?
  validates_presence_of :name, :host
  validates_length_of :name, :maximum => 64
  validates_with DataSourceNameValidator

  after_update :solr_reindex_later, :if => :shared_changed?
  after_update :create_name_changed_event, :if => :current_user

  after_create :enqueue_refresh
  after_create :create_created_event, :if => :current_user

  after_destroy :create_deleted_event, :if => :current_user

  def self.by_type(entity_types)
    if entity_types.present?
      where(type: [*entity_types].map(&:classify))
    else
      self
    end
  end

  def self.owned_by(user)
    if user.admin?
      scoped
    else
      where(:owner_id => user.id)
    end
  end

  def self.reindex_data_source(id)
    data_source = find(id)
    data_source.solr_index
    data_source.datasets(:reload => true).each(&:solr_index)
  end

  def self.unshared
    where("data_sources.shared = false OR data_sources.shared IS NULL")
  end

  def self.accessible_to(user)
    where('data_sources.shared OR data_sources.owner_id = :owned OR data_sources.id IN (:with_membership)',
          owned: user.id,
          with_membership: user.data_source_accounts.pluck(:data_source_id)
    )
  end

  def accessible_to(user)
    DataSource.accessible_to(user).include?(self)
  end

  def self.refresh_databases(data_source_id)
    find(data_source_id).refresh_databases
  end

  def self.create_for_entity_type(entity_type, user, data_source_hash)
    entity_class = entity_type.classify.constantize rescue NameError
    raise ApiValidationError.new(:entity_type, :invalid) unless entity_class < DataSource
    entity_class.create_for_user(user, data_source_hash)
  end

  def valid_db_credentials?(account)
    success = true
    connection = connect_with(account).connect!
  rescue DataSourceConnection::InvalidCredentials
    success = false
  ensure
    connection.try(:disconnect)
    success
  end

  def is_hawq_data_source?(account)
    connection = connect_with(account)
    connection.is_hawq? if is_hawq
  end

  def connect_with(account, options = {})
    connection = connection_class.new(self, account, options.reverse_merge({:logger => Rails.logger}))

    if block_given?
      connection.with_connection do
        yield connection
      end
    else
      connection
    end
  end

  def connect_as_owner
    connect_with(owner_account)
  end

  def connect_as(user)
    connect_with(account_for_user!(user))
  end

  def account_for_user(user)
    if shared?
      owner_account
    else
      account_owned_by(user)
    end
  end

  def account_for_user!(user)
    account_for_user(user) || (raise ActiveRecord::RecordNotFound)
  end

  def data_source
    self
  end

  def self.check_status(id)
    data_source = DataSource.find(id)
    data_source.check_status!
  rescue => e
    Rails.logger.error  "Unable to check status of DataSource: #{data_source.inspect}"
    Rails.logger.error "#{e.message} :  #{e.backtrace}"
  end

  def self.refresh(id, options={})
    symbolized_options = options.symbolize_keys
    symbolized_options[:new] = symbolized_options[:new].to_s == "true" if symbolized_options[:new]
    find(id).refresh symbolized_options
  end

  def refresh(options={})
    options[:skip_dataset_solr_index] = true if options[:new]
    refresh_databases options

    if options[:skip_dataset_solr_index]
      #The first refresh_all did not index the datasets in solr due to performance.
      refresh_schemas options.merge(:force_index => true)
    end
  end

  def refresh_databases_later
    SolrIndexer.SolrQC.enqueue_if_not_queued('DataSource.refresh_databases', id) unless being_destroyed?
  end

  def solr_reindex_later
    SolrIndexer.SolrQC.enqueue_if_not_queued('DataSource.reindex_data_source', id)
  end

  def update_state_and_version
    self.state = "online"
    self.version = connect_as_owner.version
  rescue  => e
    Chorus.log_error "Could not connect while updating state: #{e}: #{e.message} on #{e.backtrace[0]}"
    self.state = "offline"
  end

  def attempt_connection(user)
    # pass empty block to attempt connection and ensure connection disconnects
    # so we do not leak connections
    connect_as(user).with_connection {}
  end

  private

  def build_data_source_account_for_owner
    build_owner_account(:owner => owner, :db_username => db_username, :db_password => db_password)
  end

  def validate_owner?
    self.changed.include?('host') || self.changed.include?('port') || self.changed.include?('db_name')
  end

  def enqueue_refresh
    SolrIndexer.SolrQC.enqueue_if_not_queued("DataSource.refresh", self.id, 'new' => true)
  end

  def account_owned_by(user)
    accounts.find_by_owner_id(user.id)
  end

  def create_created_event
    Events::DataSourceCreated.by(current_user).add(:data_source => self)
  end

  def create_name_changed_event
    if name_changed?
      Events::DataSourceChangedName.by(current_user).add(
          :data_source => self,
          :old_name => name_was,
          :new_name => name
      )
    end
  end

  def create_deleted_event
    Events::DataSourceDeleted.by(current_user).add(:data_source => self)
  end
end
