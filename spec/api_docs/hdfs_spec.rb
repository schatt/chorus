require 'spec_helper'

resource "Hdfs" do
  let(:owner) { data_source.owner }
  let!(:data_source) { hdfs_data_sources(:hadoop) }
  let!(:dir_entry) { HdfsEntry.create!({:path => '/files', :modified_at => Time.current.to_s, :is_directory => "true", :content_count => "3", :hdfs_data_source => data_source}, :without_protection => true) }
  let!(:file_entry) { HdfsEntry.create!({:path => '/test.txt', :modified_at => Time.current.to_s, :size => "1234kB", :hdfs_data_source => data_source}, :without_protection => true ) }
  let(:hdfs_data_source_id) { data_source.to_param }
  let(:stats) {
    OpenStruct.new(
        'owner' => 'the_boss',
        'group' => 'the_group',
        'modified_at' => Time.parse('2012-06-06 23:02:42'),
        'accessed_at' => Time.parse('2012-06-06 23:02:42'),
        'size' => 1234098,
        'block_size' => 128,
        'permissions' => 'rw-r--r--',
        'replication' => 3
    )
  }

  before do
    log_in owner
    stub(Hdfs::QueryService).version_of(anything) { "1.0.0" }
    stub(Hdfs::QueryService).accessible?(anything) { true }

    service = Object.new
    stub(Hdfs::QueryService).for_data_source(data_source) { service }
    stub(service).show('/test.txt') { ["This is such a nice file.", "It's my favourite file.", "I could read this file all day.'"] }
    stub(HdfsEntry).list('/', data_source, true) { [dir_entry, file_entry] }
    stub(HdfsEntry).list('/files/', data_source, true) { [file_entry] }
    stub(HdfsEntry).list('/test.txt', data_source, true) { [file_entry] }
    stub(HdfsEntry).statistics { HdfsEntryStatistics.new(stats) }
  end

  post "/hdfs_data_sources" do
    parameter :name, "Name to show Chorus users for data source"
    parameter :description, "Description of data source"
    parameter :host, "Host IP or address of HDFS data source"
    parameter :port, "Port of HDFS data source"
    parameter :hdfs_version, "HDFS Version for the HDFS data source"
    parameter :username, "Username for connection to data source"
    parameter :group_list, "Group list for connection"

    let(:name) { "Sesame_Street" }
    let(:description) { "Can you tell me how to get..." }
    let(:host) { "sesame.street.local" }
    let(:port) { "8020" }
    let(:hdfs_version) { "Pivotal HD 2" }
    let(:username) { "big" }
    let(:group_list) { "bird" }

    required_parameters :name, :host, :port, :username, :group_list, :hdfs_version

    example_request "Register a HDFS data source" do
      status.should == 201
    end
  end

  put "/hdfs_data_sources/:id" do
    parameter :id, "HDFS data source id"
    parameter :name, "Name to show Chorus users for data source"
    parameter :description, "Description of data source"
    parameter :host, "Host IP or address of HDFS data source"
    parameter :port, "Port of HDFS data source"
    parameter :hdfs_version, "HDFS Version for the HDFS data source"
    parameter :username, "Username for connection to data source"
    parameter :group_list, "Group list for connection"

    let(:name) { "a22_Duck_Street" }
    let(:description) { "Quack!" }
    let(:host) { "duck.heroku.com" }
    let(:port) { "8121" }
    let(:username) { "donaldd" }
    let(:group_list) { "scroogemcduck" }
    let(:hdfs_version) { "Pivotal HD 2" }
    let(:id) { data_source.id }

    required_parameters :name, :host, :port, :username, :group_list, :hdfs_version

    example_request "Update the details on a HDFS data source" do
      status.should == 200
    end
  end

  get "/hdfs_data_sources" do
    pagination

    example_request "Get a list of registered HDFS data sources" do
      status.should == 200
    end
  end

  get "/hdfs_data_sources/:id" do
    parameter :id, "HDFS data source id"

    let(:id) { data_source.to_param }

    example_request "Get data source details"  do
      status.should == 200
    end
  end

  get "/hdfs_data_sources/:hdfs_data_source_id/files" do
    parameter :hdfs_data_source_id, "HDFS data source id"

    example_request "Get a list of files for a specific HDFS data source's root directory"  do
      status.should == 200
    end
  end

  get "/hdfs_data_sources/:hdfs_data_source_id/files/:id" do
    parameter :hdfs_data_source_id, "HDFS data source id"
    parameter :id, "HDFS file id"

    let(:id) { dir_entry.id }

    example_request "Get a list of files for a subdirectory of a specific HDFS data source"  do
      status.should == 200
    end
  end

  get "/hdfs_data_sources/:hdfs_data_source_id/files/:file_id/statistics" do
    parameter :hdfs_data_source_id, "HDFS data source id"
    parameter :file_id, "HDFS file_id"

    let(:file_id) { file_entry.id }

    example_request "Get file details for an HDFS file"  do
      status.should == 200
    end
  end

  post '/hdfs_data_sources/:hdfs_data_source_id/files/:file_id/imports' do
    parameter :hdfs_data_source_id, 'HDFS data source id'
    parameter :file_id, 'HDFS directory file_id'
    parameter :upload_id, 'Uploaded file id'

    required_parameters :upload_id

    let(:file_id) { dir_entry.id }
    let(:upload_id) { uploads(:default).id }

    example_request 'Create an import into an HDFS directory' do
      status.should == 201
    end
  end

  delete "/hdfs_data_sources/:id" do
    parameter :id, "HDFS data source id"

    let(:id) { data_source.to_param }

    example_request "Delete a HDFS data source" do
      status.should == 200
    end
  end
end

 
