require 'spec_helper'

describe ChorusConfigPresenter, :type => :view do
  let(:config) { ChorusConfig.instance }
  before do
    mock(LdapClient).enabled? { true }
    stub(File).directory? { true }
    stub.proxy(config).[](anything)
  end

  let(:presenter) { ChorusConfigPresenter.new(config, view, {}) }
  let(:hash) { presenter.to_hash}

  describe "present" do
    it "includes the ldap status" do
      stub(config).[]('ldap') { {'enabled' => true} }
      hash[:external_auth_enabled].should == true
    end

    it "includes the tableau_configured? value" do
      stub(config).tableau_configured? { 'value' }
      hash[:tableau_configured].should == 'value'
    end

    it "includes the kaggle_configured? value" do
      stub(config).kaggle_configured? { 'value' }
      hash[:kaggle_configured].should == 'value'
    end

    it "includes the alpine configuration" do
      stub(config).[]('alpine.url') { 'http://test.example.com:8080' }
      stub(config).[]('alpine.api_key') { 'abcdefg' }
      hash[:alpine_url].should == 'http://test.example.com:8080'
      hash[:alpine_api_key].should == 'abcdefg'
    end

    it "includes the work flow configuration" do
      stub(config).[]('work_flow.url') { 'http://test.example.com:8080' }
      stub(config).[]('work_flow.enabled') { true }
      hash[:work_flow_configured].should be_true
      hash[:work_flow_url].should == 'http://test.example.com:8080'
    end

    it "does not include the alpine configuration when it is not fully configured" do
      stub(config).[]('alpine.url') { '' }
      stub(config).[]('alpine.api_key') { 'abcdefg' }
      hash.should_not have_key('alpine_url')
      hash.should_not have_key('alpine_api_key')
    end

    it "includes the gnip_configured? value" do
      stub(config).gnip_configured? { 'value' }
      hash[:gnip_configured].should == 'value'
    end

    it "includes the oracle_configured? value" do
      stub(config).oracle_configured? { 'truthy' }
      hash[:oracle_configured].should == 'truthy'
    end

    it "gpfdist_configured is true when config.gpfdist_configured? is true" do
      stub(config).gpfdist_configured? { true }
      hash[:gpfdist_configured].should == true
    end

    it "gpfdist_configured is false when config.gpfdist_configured? is false" do
      stub(config).gpfdist_configured? { false }
      hash[:gpfdist_configured].should == false
    end

    it "includes the default preview row limits" do
      stub(config).[]('default_preview_row_limit') { 12 }
      hash[:default_preview_row_limit].should == 12
    end

    it "includes the execution timeout" do
      stub(config).[]('execution_timeout_in_minutes') { 3 }
      hash[:execution_timeout_in_minutes].should == 3
    end

    it "includes the file size maximums" do
      stub(config).[]('file_sizes_mb.csv_imports') { 1 }
      stub(config).[]('file_sizes_mb.workfiles') { 10 }
      stub(config).[]('file_sizes_mb.user_icon') { 5 }
      stub(config).[]('file_sizes_mb.workspace_icon') { 5 }
      stub(config).[]('file_sizes_mb.attachment') { 10 }
      hash[:file_sizes_mb_csv_imports].should == 1
      hash[:file_sizes_mb_workfiles].should == 10
      hash[:file_sizes_mb_user_icon].should == 5
      hash[:file_sizes_mb_workspace_icon].should == 5
      hash[:file_sizes_mb_attachment].should == 10
    end

    it "includes the visualization overlay string" do
      stub(config).[]('visualization.overlay_string') { 'FOR OFFICIAL USE ONLY'*50 }

      hash[:visualization_overlay_string].should == ('FOR OFFICIAL USE ONLY'*50)[0...40]
    end
  end
end