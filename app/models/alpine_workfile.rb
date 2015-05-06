require 'set'

class AlpineWorkfile < Workfile
  TooManyDataBases = Class.new(StandardError)

  RUNNING = 'running'
  IDLE = 'idle'

  has_additional_data :dataset_ids, :killable_id
  has_many :workfile_execution_locations, foreign_key: :workfile_id, dependent: :destroy

  before_validation { self.content_type ='work_flow' }
  after_create :determine_execution_location
  validates_with AlpineWorkfileValidator
  validate :ensure_active_workspace, :on => :create

  after_destroy :notify_alpine_of_deletion

  def execution_locations
    workfile_execution_locations.map(&:execution_location)
  end

  def entity_subtype
    'alpine'
  end

  def attempt_data_source_connection
    data_sources.each do |ds|
      ds.attempt_connection(current_user)
    end
  end

  def data_sources
    execution_locations.map(&:data_source).compact
  end

  def update_from_params!(params)
    update_execution_location(params) if params[:execution_locations].present?
    update_file_name(params)
    Workfile.transaction do
      save!
      notify_alpine_of_upload(scoop_file_from(params)) if (!params[:file_name] && params[:versions_attributes].present?)
    end
  rescue Net::ProtocolError, SocketError, Errno::ECONNREFUSED, TimeoutError => e
    raise ApiValidationError.new(:base, :alpine_connection_error)
  end

  def datasets
    @datasets ||= Dataset.where(:id => dataset_ids)
  end

  def live_dataset_ids
    datasets.map &:id
  end

  def create_new_version(user, params)
    Events::WorkFlowUpgradedVersion.by(user).add(
      :workfile => self,
      :workspace => workspace,
      :commit_message => params[:commit_message]
    )
  end

  def run_now(user)
    process_id = Alpine::API.run_work_flow(self, user)
    update_attributes(status: RUNNING, killable_id: process_id) unless process_id.empty?
    process_id
  end

  def stop_now(user)
    response = Alpine::API.stop_work_flow(self, user)
    update_attribute(:status, IDLE) if response.code == '200'
    response
  end

  def copy!(user, workspace, new_file_name=nil)
    AlpineWorkfile.transaction do
      new_workfile = super
      Alpine::API.copy_work_flow(self, new_workfile.id)
      new_workfile
    end
  end

  def copy(user, workspace, new_file_name = nil)
    new_workfile = super
    new_workfile.dataset_ids = []
    workfile_execution_locations.each do |location|
      new_workfile.workfile_execution_locations.build(:execution_location => location.execution_location)
    end

    new_workfile
  end

  private

  def update_file_name(params)
    self.resolve_name_conflicts = !params[:file_name]
    self.file_name = scoop_file_name(params) if params[:versions_attributes]
  end

  def scoop_file_name(params)
    full_name = params[:versions_attributes][0][:contents].original_filename
    full_name.gsub('.afm', '')
  end

  def scoop_file_from(params)
    params[:versions_attributes][0][:contents].read
  end

  def update_execution_location(params)
    workfile_execution_locations.destroy_all

    params[:execution_locations].each do |location|
      source = case location[:entity_type]
                 when 'gpdb_database', 'pg_database' then
                   Database.find location[:id]
                 when 'hdfs_data_source' then
                   HdfsDataSource.find location[:id]
                 when 'oracle_data_source', 'jdbc_data_source', 'jdbc_hive_data_source' then
                   DataSource.where(:type => %w(OracleDataSource JdbcDataSource JdbcHiveDataSource)).find location[:id]
                 else #nil
               end

      workfile_execution_locations.build(:execution_location => source)
    end
  end

  def determine_execution_location
    unless datasets.empty?
      sources = datasets.map(&:execution_location)

      sources.uniq.each do |source|
        workfile_execution_locations.create!(:execution_location => source)
      end
    end
  end

  def notify_alpine_of_deletion
    # This will only work in development mode if you have alpine running locally and you have
    # config.threadsafe! or config.allow_concurrency = true in your config/environments/development.rb
    # Otherwise, this will time out.
    Alpine::API.delete_work_flow(self)
  end

  def notify_alpine_of_upload(file_contents)
    Alpine::API.create_work_flow(self, file_contents)
  end

  def ensure_active_workspace
    self.errors[:workspace] << :ARCHIVED if workspace && workspace.archived?
  end
end
