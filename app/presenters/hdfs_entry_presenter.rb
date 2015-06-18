class HdfsEntryPresenter < Presenter
  def to_hash
    hash = {
        :id => model.id,
        :size => model.size,
        :name => model.name,
        :is_dir => model.is_directory,
        :is_binary => false,
        :last_updated_stamp => model.modified_at.nil? ? "" : model.modified_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
        :entity_type => model.entity_type_name,
        :hdfs_data_source => present(model.hdfs_data_source, options),
        :is_deleted => model.deleted?
    }

    unless succinct?
      hash.merge!({
        :ancestors => model.ancestors,
        :path => model.parent_path,
      }.merge(tags_hash))
    end

    if model.is_directory
      hash[:entries] = present model.entries(true) if options[:deep]
      hash[:count] = model.content_count
    else
      hash[:contents] = model.contents if options[:deep]
    end

    hash
  end

  def complete_json?
    !model.is_directory || options[:deep]
  end

  private

  def tags_hash
    rendering_activities? ? {} : {:tags => present(model.tags)}
  end
end
