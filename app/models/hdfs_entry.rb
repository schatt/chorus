class HdfsEntry < ActiveRecord::Base
  include Stale
  include Notable
  include TaggableBehavior
  include SoftDelete

  attr_accessible :path

  has_many :activities, :as => :entity
  has_many :events, :through => :activities

  belongs_to :hdfs_data_source
  belongs_to :parent, :class_name => HdfsEntry, :foreign_key => 'parent_id'
  has_many :children, :class_name => HdfsEntry, :foreign_key => 'parent_id'

  validates_uniqueness_of :path, :scope => :hdfs_data_source_id
  validates_presence_of :hdfs_data_source
  validates_format_of :path, :with => %r{\A/.*}
  validates_length_of :path, :maximum => 4096

  scope :files, where(:is_directory => false)

  attr_accessor :highlighted_attributes, :search_result_notes
  searchable_model :unless => lambda { |model| model.is_directory? || model.stale? } do
    text :name, :stored => true, :boost => SOLR_PRIMARY_FIELD_BOOST
    text :parent_name, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
  end

  before_create :build_full_path

  HdfsContentsError = Class.new(StandardError)

  def self.destroy_entries(data_source_id)
    # Don't use dependent => destroy because it pulls them all into memory
    HdfsEntry.where(:hdfs_data_source_id => data_source_id).find_each do |entry|
      entry.destroy
    end
  end

  def name
    File.basename(path)
  end

  def parent_name
    File.basename(File.dirname(path))
  end

  def ancestors
    #return @ancestors if @ancestors
    @ancestors = []
    if parent
      parent_name = parent.path == '/' ? hdfs_data_source.name : parent.name
      @ancestors << {:name => parent_name, :id => parent_id}
      @ancestors += parent.ancestors
    end
    @ancestors
  end

  def highlighted_attributes
    @highlighted_attributes.merge(:path => [highlighted_path])
  end

  def highlighted_path
    dir = @highlighted_attributes.key?(:parent_name) ? @highlighted_attributes[:parent_name].first : parent_name

    *rest, dir_name, file_name = path.split("/")
    rest << dir
    rest.join('/')
  end

  def modified_at=(new_time)
    if modified_at != new_time
      super
    end
  end

  def self.list(path, hdfs_data_source, delay_mark_stale = false)
    query_service = Hdfs::QueryService.for_data_source(hdfs_data_source, current_user ? current_user.username : '')
    current_entries = query_service.list(path).map do |result|
      hdfs_entry = hdfs_data_source.hdfs_entries.find_or_initialize_by_path(result["path"])
      hdfs_entry.stale_at = nil if hdfs_entry.stale?
      hdfs_entry.hdfs_data_source = hdfs_data_source
      hdfs_entry.assign_attributes(result, :without_protection => true)
      hdfs_entry.save! if hdfs_entry.changed?
      hdfs_entry
    end

    current_entry_ids = current_entries.map(&:id)

    # The operation of marking stale hdfs_entries can take a long time, so in the interest of saving time, if delay_mark_stale is set to true,
    # we will put the operation in the queue so that the user is not waiting such a long time for results to come back.
    # In general, delay_mark_stale will be false for refresh operations, like those done in solr indexing operations
    # When we reach this from the hdfs_entry_presenter class, since we know it is coming from a user interaction, delay_mark_stale will be set to true
    if(delay_mark_stale)
      QC.enqueue("HdfsEntry.mark_stale_entries", hdfs_data_source.id, path, current_entry_ids)
    else
      self.mark_stale_entries(hdfs_data_source.id, path, current_entry_ids)
    end

    current_entries
  end

  # For any hdfs_entries we find in the DB that are no longer present in the actual hdfs path, we will mark these entries as stale
  def self.mark_stale_entries(hdfs_data_source_id, path, current_entry_ids)
    hdfs_data_source = HdfsDataSource.find(hdfs_data_source_id)
    parent = hdfs_data_source.hdfs_entries.find_by_path(normalize_path(path))
    finder = parent.children
    finder = finder.where(['id not in (?)', current_entry_ids]) unless current_entry_ids.empty?
    finder.each do |hdfs_entry|
      hdfs_entry.mark_stale!
      next unless hdfs_entry.is_directory?
      hdfs_data_source.hdfs_entries.where("stale_at IS NULL AND path LIKE ?", "#{hdfs_entry.path}/%").find_each do |entry_to_mark_stale|
        entry_to_mark_stale.mark_stale!
      end
    end
  end

  def entries(delay_mark_stale = false)
    HdfsEntry.list(path.chomp('/') + '/', hdfs_data_source, delay_mark_stale)
  end
  alias_method :refresh, :entries


  def self.statistics(path, hdfs_data_source)
    query_service = Hdfs::QueryService.for_data_source(hdfs_data_source, current_user ? current_user.username : '')
    stats = query_service.details(path)
    HdfsEntryStatistics.new stats
  end

  def statistics
    HdfsEntry.statistics(path.chomp('/'), hdfs_data_source)
  end

  def contents
    query_service = Hdfs::QueryService.for_data_source(hdfs_data_source, current_user ? current_user.username : '')
    query_service.show(path)
  rescue StandardError => e
    raise HdfsContentsError.new(e)
  end

  def file
    unless is_directory?
      HdfsFile.new(path, hdfs_data_source, {
          :modified_at => modified_at
      })
    end
  end

  def parent_path
    File.dirname(path)
  end

  def entity_type_name
    'hdfs_file'
  end

  private

  def self.normalize_path(path)
    Pathname.new(path).cleanpath.to_s
  end

  def build_full_path
    return true if path == "/"
    self.parent = hdfs_data_source.hdfs_entries.find_or_create_by_path(parent_path)
    self.parent.is_directory = true
    self.parent.save!
  end
end
