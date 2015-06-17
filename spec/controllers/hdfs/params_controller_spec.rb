#require "spec_helper"
#
#describe Hdfs::ParamsController do
#  let(:hdfs_data_source) { hdfs_data_sources(:hadoop) }
#
#  before do
#    log_in users(:owner)
#  end
#
#  describe "index" do
#    let(:hadoop_conf_params) { OpenStruct.new(FactoryGirl.attributes_for(:hdfs_param_fetch)) }
#
#    before do
#      # Todo: Mock the hadoopconf fetch and properties.
#    end
#
#    it "should retrieve the properties for a host and config" do
#      get :index, :host => hdfs_data_source.host, :port => 8088
#
#      response.code.should == '200'
#      # Todo: Check that decoded_response.params is proper.
#    end
#
#    it "should handle junk parameters gracefully" do
#      # Todo
#    end
#
#    generate_fixture "hdfsParamFetch.json" do
#      get :index, :host => hdfs_data_source.host, :port => 8088
#    end
#  end
#end
