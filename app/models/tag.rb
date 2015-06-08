class Tag < ActiveRecord::Base
  has_many :taggables, :through => :taggings
  has_many :taggings
  belongs_to :workfile, :touch => true
  belongs_to :dataset, :touch => true

  attr_accessible :name
  attr_accessor :highlighted_attributes, :search_result_notes

  validates_uniqueness_of :name, :case_sensitive => false
  validates_length_of :name, :maximum => 100, :minimum => 1
  validate :no_commas_in_name

  after_update :reindex_tagged_objects
  before_destroy do
    reindex_tagged_objects
    taggings.destroy_all
  end

  searchable do
    string :type_name
    text :name, :stored => true, :boost => SOLR_PRIMARY_FIELD_BOOST
  end

  def self.named_like(name)
    where(["name ILIKE ?", "%#{name}%"])
  end

  def self.reset_all_counters
    find_each { |tag| Tag.reset_counters(tag.id, :taggings) }
  end

  def self.find_or_create_by_tag_name(name)
    self.where("UPPER(name) = UPPER(?)", name).first_or_create!(:name => name)
  end

  private

  def no_commas_in_name
    errors.add(:name, :invalid) if name =~ /,/
  end

  def reindex_tagged_objects
    taggings = Tagging.where(tag_id: id)
    objects_to_reindex = taggings.map(&:taggable).map do |obj|
      [obj.class.to_s, obj.id]
    end
    SolrIndexer.SolrQC.enqueue_if_not_queued("SolrIndexer.reindex_objects", objects_to_reindex)
  end
end
