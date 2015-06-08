require 'render_anywhere'

class Workspace < ActiveRecord::Base
  include SoftDelete
  include TaggableBehavior
  include Notable
  include RenderAnywhere

  PROJECT_STATUSES = [:on_track, :needs_attention, :at_risk]

  attr_accessible :name, :public, :summary, :member_ids, :has_added_member, :owner_id, :archiver, :archived,
                  :has_changed_settings, :show_sandbox_datasets, :is_project, :project_status, :project_status_reason,
                  :project_target_date

  has_attached_file :image, :path => ":rails_root/system/:class/:id/:style/:basename.:extension",
                    :url => "/:class/:id/image?style=:style",
                    :default_url => "", :styles => {:icon => "50x50>"}

  belongs_to :archiver, :class_name => 'User', :touch => true
  belongs_to :owner, :class_name => 'User', :touch => true
  has_many :jobs, :dependent => :destroy
  has_many :milestones, :dependent => :destroy
  has_many :memberships, :inverse_of => :workspace
  has_many :members, :through => :memberships, :source => :user
  has_many :workfiles, :dependent => :destroy
  has_many :activities, :as => :entity
  has_many :events, :through => :activities
  has_many :owned_notes, :class_name => 'Events::Base', :conditions => "events.action ILIKE 'Events::Note%'"
  has_many :owned_events, :class_name => 'Events::Base'
  has_many :comments, :through => :owned_events
  has_many :chorus_views, :dependent => :destroy
  belongs_to :sandbox, :class_name => 'Schema', :conditions => { :type => %w(GpdbSchema PgSchema) }

  has_many :csv_files

  has_many :directly_associated_datasets, :dependent => :destroy, :class_name => 'Dataset'
  has_many :associated_datasets, :dependent => :destroy
  has_many :source_datasets, :through => :associated_datasets, :source => :dataset
  has_many :all_imports, :class_name => 'Import'
  has_many :imports, :class_name => 'WorkspaceImport'

  validates_presence_of :name
  validate :uniqueness_of_workspace_name
  validate :owner_is_member, :on => :update
  validate :archiver_is_set_when_archiving
  validates_attachment_size :image, :less_than => ChorusConfig.instance['file_sizes_mb']['workspace_icon'].megabytes, :message => :file_size_exceeded
  validates_with MemberCountValidator

  before_update :reindex_sandbox, :if => :show_sandbox_datasets_changed?
  before_update :create_name_change_event, :if => :name_changed?
  before_update :disassociate_source_datasets_in_sandbox, :if => 'sandbox_id_changed? || show_sandbox_datasets_changed?'

  before_save :handle_archiving, :if => :archived_changed?
  before_save :update_has_added_sandbox
  after_create :add_owner_as_member

  scope :active, where(:archived_at => nil)

  after_update :solr_reindex_later, :if => :public_changed?
  # PT 12/19/14 This will auto-refresh the JSON data object for workspace
  after_save :delete_cache

  attr_accessor :highlighted_attributes, :search_result_notes
  searchable_model do
    text :name, :stored => true, :boost => SOLR_PRIMARY_FIELD_BOOST
    text :summary, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
  end

  def self.reindex_workspace(workspace_id)
    workspace = find(workspace_id)
    workspace.solr_index
    workspace.workfiles(:reload => true).each(&:solr_index)
    workspace.owned_notes(:reload => true).each(&:solr_index)
    workspace.comments(:reload => true).each(&:solr_index)
  end

  def self.eager_load_associations
    [{:owner => :tags},
     :archiver,
     :tags,
     :owner,
     {:sandbox => {:scoped_parent => {:data_source => [:tags, {:owner => :tags}]}}}
    ]
  end

  def delete_cache(user = nil)

    if self.id != nil && user != nil
      cache_key = "home:workspaces/Users/#{user.id}/#{self.class.name}/#{self.id}-#{(self.updated_at.to_f * 1000).round(0)}"
      Chorus.log_debug "-- BEFORE SAVE: Clearing cache for #{self.class.name} with cache key = #{cache_key} --"
      Rails.cache.delete(cache_key)
      cache_key = "workspaces:workspaces/Users/#{user.id}/#{self.class.name}/#{self.id}-#{(self.updated_at.to_f * 1000).round(0)}"
      Rails.cache.delete(cache_key)
      return true
    elsif self.id != nil && current_user != nil
      #Fix for 87339340. Avoid searching for cache if the record is newly created and does have an ID before saving to database.
      cache_key = "home:workspaces/Users/#{current_user.id}/#{self.class.name}/#{self.id}-#{(self.updated_at.to_f * 1000).round(0)}"
      Chorus.log_debug "-- BEFORE SAVE: Clearing cache for #{self.class.name} with cache key = #{cache_key} --"
      Rails.cache.delete(cache_key)
      cache_key = "workspaces:workspaces/Users/#{current_user.id}/#{self.class.name}/#{self.id}-#{(self.updated_at.to_f * 1000).round(0)}"
      Rails.cache.delete(cache_key)
      return true
    end
  end


  def solr_reindex_later
    SolrIndexer.SolrQC.enqueue_if_not_queued('Workspace.reindex_workspace', id)
  end

  has_shared_search_fields [
    { :type => :integer, :name => :member_ids, :options => { :multiple => true } },
    { :type => :boolean, :name => :public },
    { :type => :integer, :name => :workspace_id, :options => { :multiple => true, :using => :id} }
  ]

  def self.add_search_permissions(current_user, search)
    unless current_user.admin?
      search.build do
        any_of do
          without :security_type_name, Workspace.security_type_name
          with :member_ids, current_user.id
          with :public, true
        end
      end
    end
  end

  def uniqueness_of_workspace_name
    if self.name
      other_workspace = Workspace.where("lower(name) = ?", self.name.downcase)
      other_workspace = other_workspace.where("id != ?", self.id) if self.id
      if other_workspace.present?
        errors.add(:name, :taken)
      end
    end
  end

  def scope_to_database(datasets, database_id = nil)
    if database_id
      datasets.joins(:scoped_schema).where(:schemas => { :parent_id => database_id })
    else
      datasets
    end
  end

  def filtered_workfiles(params)
    filtered_workfiles = self.workfiles.order_by(params[:order]).includes(:latest_workfile_version)
    filtered_workfiles = filtered_workfiles.with_file_type(params[:file_type]) if params[:file_type].present?
    filtered_workfiles = filtered_workfiles.where("workfiles.file_name LIKE ?", "%#{params[:name_pattern]}%") if params[:name_pattern]
    filtered_workfiles.includes(Workfile.eager_load_associations)
  end

  def filtered_datasets(options = {})
    entity_subtype = options[:entity_subtype]
    entity_subtype = 'SANDBOX_TABLE' if options[:all_import_destinations]
    entity_subtype = 'SOURCE_TABLE' if options[:all_import_sources]
    database_id = options[:database_id]

    scoped_datasets = scope_to_database(source_datasets, database_id)
    scoped_source_datasets = sandbox_id ? scoped_datasets.where('schema_id != ?', sandbox_id) : scoped_datasets
    scoped_directly_associated_datasets = scope_to_database(directly_associated_datasets, database_id)

    datasets = []
    case entity_subtype
      when 'SANDBOX_TABLE', 'SANDBOX_DATASET' then
      when 'CHORUS_VIEW' then
        datasets << chorus_views
      when 'SOURCE_TABLE', 'NON_CHORUS_VIEW' then
        datasets << scoped_source_datasets
      else
        datasets << scoped_datasets << scoped_directly_associated_datasets
    end

    if options[:all_import_sources]
      datasets << chorus_views
    end

    datasets.map do |relation|
      relation = relation.with_name_like options[:name_filter] if options[:name_filter]
      relation = relation.where(:id => options[:dataset_ids]) if options[:dataset_ids]
      relation = relation.where('type NOT IN (?)', %w(JdbcTable JdbcView)) if options[:all_import_sources]
      relation
    end
  end

  def with_filtered_datasets(user, options = {})
    options.merge!(:tables_only => true) if options[:entity_subtype] == 'SANDBOX_TABLE'

    account = sandbox && sandbox.database.account_for_user(user)

    datasets = filtered_datasets(options)
    yield datasets, options, account, skip_sandbox?(options, account)
  end

  def dataset_count(user, options = {})
    unlimited_options = options.dup
    unlimited_options.delete(:limit)
    with_filtered_datasets(user, unlimited_options) do |datasets, new_options, account, skip_sandbox|
      count = datasets.map(&:count).reduce(0, &:+)
      begin
        count += sandbox.dataset_count(account, new_options) unless skip_sandbox
      rescue DataSourceConnection::InvalidCredentials
        #do nothing
      rescue Exception => e
        #do nothing
      ensure
        count
      end
      count
    end
  end

  def datasets(current_user, options = {})
    with_filtered_datasets(current_user, options) do |datasets, new_options, account, skip_sandbox|
      begin
        datasets << GpdbDataset.visible_to(account, sandbox, new_options) unless skip_sandbox
      rescue DataSourceConnection::InvalidCredentials
        # This is in case a user has invalid credentials, but hasn't tried to use them since becoming invalid
      end
      if datasets.count == 1 # return intact relations for optimization
        datasets.first
      else
        Dataset.where(:id => datasets.flatten)
      end
    end
  end

  def self.create_for_user(user, params)
    workspace = user.owned_workspaces.build(params)
    Workspace.transaction do
      workspace.save!
      workspace.public ?
          Events::PublicWorkspaceCreated.by(user).add(:workspace => workspace) :
          Events::PrivateWorkspaceCreated.by(user).add(:workspace => workspace)
    end
    workspace
  end

  def self.workspaces_for(user)
    if user.admin?
      scoped
    else
      accessible_to(user)
    end
  end

  def self.accessible_to(user)
    with_membership = user.memberships.pluck(:workspace_id)
    where('workspaces.public OR
          workspaces.id IN (:with_membership) OR
          workspaces.owner_id = :user_id',
          :with_membership => with_membership,
          :user_id => user.id
         )
  end

  def members_accessible_to(user)
    if public? || members.include?(user)
      members
    else
      []
    end
  end

  def permissions_for(user)
    has_membership = user.memberships.find_by_workspace_id(id)
    perm = if user.admin? || (owner_id == user.id)
      [:admin]
    elsif has_membership
      [:read, :commenting, :update, :duplicate_chorus_view]
    elsif public?
      [:read, :commenting]
    else
      []
    end
    perm << :create_workflow if user.developer? && has_membership
    perm
  end

  def has_dataset?(dataset)
    in_sandbox         = dataset.schema == sandbox && !sandbox.nil?
    in_source_datasets = source_datasets.include?(dataset)

    (in_sandbox && show_sandbox_datasets) || in_source_datasets
  end

  def member?(user)
    user.memberships.find_by_workspace_id(id).present?
  end

  def archiver=(value)
    if value.nil? || (value.is_a? User)
      super
    end
  end

  def is_deleted?
    deleted_at != nil ? true : false
  end

  def visible_to?(user)
    public? || member?(user)
  end

  def associate_datasets(user, datasets)
    #TODO: Take single datasets
    should_raise_errors = (datasets.length == 1)
    Workspace.transaction do
      datasets.each do |dataset|
        raise ActiveRecord::Rollback unless dataset.associable?

        association = associated_datasets.build
        association.dataset = dataset
        should_raise_errors ? association.save! : association.save

        create_event_for_dataset(user, dataset) if association.valid?
      end
    end
  end

  #Added by Prakash Teli 12/12/14
  def latest_comments_hash

    recent_notes = owned_notes.recent.order("updated_at desc").limit(3)
    recent_comments = comments.recent.order("updated_at desc").limit(3)

    recent_insights = recent_notes.where(:insight => true)

    #recent_notes_and_comments = recent_notes.order("updated_at desc").limit(5) + recent_comments.order("updated_at desc").limit(5)
    #latest_5 = recent_notes_and_comments.sort_by(&:updated_at).last(5)

    # TODO: Providing the "number_of_insights", "number_of_comments" below in addition to
    #       the recent_insights_count and recent_comment_counts above with the same intention
    #       but slightly different implementation. Needs to be refactored.
    {
        :number_of_insights => recent_insights.size,
        :number_of_comments => recent_notes.size + recent_comments.size - recent_insights.size,
        :latest_comment_list => recent_comments,
        :latest_notes_list => recent_notes,
        :latest_insight => owned_notes.order("updated_at desc").where(:insight => true).first,
        #:latest_comment_list => present(latest_5),
        #:latest_insight => present(model.owned_notes.order("updated_at desc").where(:insight => true).first)
    }

  end


  private

  def reindex_sandbox
    SolrIndexer.SolrQC.enqueue_if_not_queued("Schema.reindex_datasets", sandbox.id) if sandbox
  end

  def skip_sandbox?(options, account)
    options ||= {}
    entity_subtype = options[:entity_subtype]

    (!account || account.invalid_credentials? ||
        %w(CHORUS_VIEW SOURCE_TABLE).include?(entity_subtype) ||
        !show_sandbox_datasets) && !options[:all_import_destinations]
  end

  def owner_is_member
    unless members.include? owner
      errors.add(:owner, "Owner must be a member")
    end
  end

  def add_owner_as_member
    unless members.include? owner
      memberships.create!({ :user => owner, :workspace => self }, { :without_protection => true })
    end
  end

  def archiver_is_set_when_archiving
    if archived? && !archiver
      errors.add(:archived, "Archiver is required for archiving")
    end
  end

  def handle_archiving
    if archived?
      self.archived_at = Time.current
    else
      self.archived_at = nil
      self.archiver = nil
    end
  end

  def update_has_added_sandbox
    self.has_added_sandbox = true if sandbox_id_changed? && sandbox
    true
  end
  def create_name_change_event
    create_workspace_name_change_event
  end

  def disassociate_source_datasets_in_sandbox
    return true unless sandbox && show_sandbox_datasets
    source_datasets.each do |source_dataset|
      source_datasets.destroy(source_dataset) if sandbox.datasets.include? source_dataset
    end
    true
  end

  def create_workspace_name_change_event
    Events::WorkspaceChangeName.by(current_user).add(:workspace => self, :workspace_old_name => self.name_was)
  end

  def create_event_for_dataset(user, dataset)
    Events::SourceTableCreated.by(user).add(
        :dataset => dataset,
        :workspace => self
    )
  end
end
