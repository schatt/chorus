require 'spec_helper'

resource 'HdfsParams' do
  before do
    log_in users(:owner)
  end

  get "/hdfs_params" do
    parameter :host, "Hadoop Resource Manager Host"
    parameter :port, "Hadoop Resource Manager Port"

    required_parameters :host, :port

    let(:host) { HdfsDataSource.host }
    let(:port) { 8088 }

    example_request "Fetch properties from hadoop resource manager" do
      status.should == 200
    end
  end
end