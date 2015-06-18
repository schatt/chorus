require "spec_helper"

describe Hdfs::FilesController do
  let(:hdfs_data_source) { hdfs_data_sources(:hadoop) }
  let(:entry) { hdfs_entries(:directory) }

  before do
    log_in users(:owner)
  end

  describe "index" do
    it "renders the list of entries on root" do
      mock(HdfsEntry).list('/', hdfs_data_source, true) { [entry] }
      entry
      get :index, :hdfs_data_source_id => hdfs_data_source.id

      response.code.should == "200"
      parsed_response = JSON.parse(response.body)
      parsed_response.should have(1).item
    end

    it "takes an id and renders the list of entries inside that directory" do
      parent_entry = HdfsEntry.create!({:is_directory => true, :path => '/data2', :hdfs_data_source => hdfs_data_source}, :without_protection => true)
      child_entry = HdfsEntry.create!({:is_directory => false, :path => '/data2/test.csv', :parent_id => parent_entry.id, :hdfs_data_source => hdfs_data_source}, :without_protection => true)

      any_instance_of(Hdfs::QueryService) do |h|
        stub(h).show { ["a, b, c", "row1a, row1b, row1c"] }
      end

      get :index, :hdfs_data_source_id => hdfs_data_source.id, :id => parent_entry.id
      decoded_response.length.should == 1
    end
  end

  describe "show" do
    context "a directory" do
      before do
        mock(HdfsEntry).list('/data/', hdfs_data_source, true) { [ hdfs_entries(:directory), hdfs_entries(:hdfs_file) ] }
      end

      it "renders the path correctly, appending slashes" do
        get :show, :hdfs_data_source_id => hdfs_data_source.id, :id => entry.id

        response.code.should == "200"
        parsed_response = JSON.parse(response.body)
        parsed_response.should have(1).item
      end

      generate_fixture "hdfsDir.json" do
        get :show, :hdfs_data_source_id => hdfs_data_source.id, :id => entry.id
      end
    end

    context "a file" do
      let(:entry) { hdfs_entries(:hdfs_file) }

      before do
        any_instance_of(Hdfs::QueryService) do |h|
          stub(h).show { ["a, b, c", "row1a, row1b, row1c"] }
        end
      end

      it "shows file content" do
        get :show, :hdfs_data_source_id => hdfs_data_source.id, :id => entry.id
        response.code.should == '200'
        decoded_response[:last_updated_stamp].should_not be_blank
        decoded_response[:contents].should include('a, b, c')
      end

      generate_fixture "hdfsFile.json" do
        get :show, :hdfs_data_source_id => hdfs_data_source.id, :id => entry.id
      end

      context "when Hdfs generates an error" do
        before do
          any_instance_of(HdfsEntry) do |entry|
            stub(entry).contents { raise HdfsEntry::HdfsContentsError.new }
          end
        end

        it "shows file with an error and without contents" do
          get :show, :hdfs_data_source_id => hdfs_data_source.id, :id => entry.id
          response.code.should == '422'
          decoded_errors[:record].should == "HDFS_CONTENTS_UNAVAILABLE"
          response.should have_presented entry
        end

        generate_fixture "hdfsContentsError.json" do
          get :show, :hdfs_data_source_id => hdfs_data_source.id, :id => entry.id
        end
      end
    end
  end
end
