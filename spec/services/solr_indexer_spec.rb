require 'spec_helper'

describe SolrIndexer do
  describe ".refresh_external_data" do
    it "refreshes Oracle, Gpdb, and Hadoop Data Sources" do
      DataSource.pluck(:id).each do |id|
        mock(SolrIndexer.SolrQC).enqueue_if_not_queued("DataSource.refresh", id, 'mark_stale' => true, 'force_index' => false)
      end

      HdfsDataSource.pluck(:id).each do |id|
        mock(SolrIndexer.SolrQC).enqueue_if_not_queued("HdfsDataSource.refresh", id)
      end

      SolrIndexer.refresh_external_data
    end
  end

  describe ".reindex" do
    before do
      mock(Sunspot).commit
    end

    context "when passed one type to index" do
      it "should reindex datasets" do
        mock(Dataset).solr_reindex
        SolrIndexer.reindex('Dataset')
      end
    end

    context "when passed more than one type to index" do
      it "should index all types" do
        mock(Dataset).solr_reindex
        mock(GpdbDataSource).solr_reindex
        SolrIndexer.reindex(['Dataset', 'GpdbDataSource'])
      end
    end

    context "when told to index all indexable types" do
      it "should index all types" do
        Sunspot.searchable.each do |type|
          mock(type).solr_reindex
        end
        SolrIndexer.reindex('all')
      end
    end

    context "when passes an empty string" do
      it "should index nothing" do
        mock.proxy(SolrIndexer).types_to_index("") do |results|
          results.should be_empty
          results
        end
        SolrIndexer.reindex('')
      end
    end
  end

  describe ".refresh_and_reindex" do
    it "calls refresh, and passes the given models to reindex" do
      mock(SolrIndexer).refresh_external_data
      mock(SolrIndexer).reindex("Model")
      SolrIndexer.refresh_and_reindex("Model")
    end
  end

  describe ".reindex_objects" do
    let(:model_1) { workfiles(:public) }
    let(:model_2) { workspaces(:public) }
    let(:job_args) { [
        [model_1.class.to_s, model_1.id],
        [model_2.class.to_s, model_2.id],
    ] }

    before do
      mock(Sunspot).commit
    end

    it "reindexes objects that are tagged with the tag" do
      mock(Sunspot).index([model_1, model_2])
      SolrIndexer.reindex_objects(job_args)
    end

    it "ignores bad ids" do
      mock(Sunspot).index([model_2])
      job_args[0][1] = 123456789
      SolrIndexer.reindex_objects(job_args)
    end
  end
end
