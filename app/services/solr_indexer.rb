module SolrIndexer
  class QCStub
    def enqueue_if_not_queued(*args)
      SolrIndexer.log("Skipped indexer enqueue (See indexer.enabled in chorus.properties). Args: #{args}")
    end
  end

  def self.SolrQC
    if ChorusConfig.instance['indexer'] && ChorusConfig.instance['indexer']['enabled'] == false
      @@SolrQC ||= QCStub.new
    else
      @@SolrQC ||= QC::Queue.new("indexer_queue")
    end

    @@SolrQC
  end

  def self.refresh_and_reindex(types)
    self.refresh_external_data
    self.reindex(types)
  end

  def self.reindex(types)
    self.log("Starting Solr Full Re-Index")
    types_to_index(types).each(&:solr_reindex)
    Sunspot.commit
    self.log("Solr Full Re-Index Completed")
  end

  def self.refresh_external_data
    self.log("Starting Solr Refresh")
    DataSource.find_each do |ds|
      self.SolrQC.enqueue_if_not_queued("DataSource.refresh", ds.id, 'mark_stale' => true, 'force_index' => false)
    end
    HdfsDataSource.find_each do |ds|
      self.SolrQC.enqueue_if_not_queued("HdfsDataSource.refresh", ds.id)
    end
    self.log("Solr Refreshes Queued")
  end

  def self.reindex_objects(object_identifiers)
    self.log("Starting Solr Partial Reindex")
    objects = object_identifiers.map do |ary|
      begin
        klass = ary[0].constantize
        id = ary[1]
        klass.find(id)
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
    objects.compact!
    Sunspot.index objects
    Sunspot.commit
    self.log("Solr Partial Reindex Completed")
  end

  private

  def self.log(message)
    Rails.logger.debug(message)
  end

  def self.types_to_index(types)
    types = Array(types)
    types = types.reject { |t| t.blank? }

    if types.include? "all"
      Sunspot.searchable
    else
      types.map(&:constantize)
    end
  end
end