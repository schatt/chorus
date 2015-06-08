require 'spec_helper'

describe OracleDataSource do
  let(:data_source) { data_sources(:oracle) }

  describe "validations" do
    it { should validate_presence_of(:host) }

    context 'when creating' do
      let(:data_source) { FactoryGirl.build(:oracle_data_source) }
      it 'validates the owner account' do
        mock(data_source).owner_account { mock(FactoryGirl.build(:data_source_account)).valid? { true } }
        data_source.valid?
      end
    end
  end

  describe "destroy" do
    it "enqueues a destroy_schemas job" do
      data_source = data_sources(:oracle)
      mock(QC.default_queue).enqueue_if_not_queued("OracleSchema.destroy_schemas", data_source.id)
      data_source.destroy
    end

    it "cancels any imports" do
      import = imports(:oracle)
      import.success.should be_nil
      data_source.destroy
      import.reload.success.should == false
    end

    it "removes itself from the execution location field of any workfiles it owns" do
      workfiles = data_source.workfile_execution_locations.all
      workfiles.length.should > 0

      expect {
        data_source.destroy
      }.to change { WorkfileExecutionLocation.where(execution_location_id: data_source.id, execution_location_type: data_source.class.base_class.name).count }.from(workfiles.length).to(0)
    end

  end

  describe "owner_account" do
    it "is created automatically" do
      data_source = FactoryGirl.build(:oracle_data_source, :owner_account => nil)
      stub(data_source).valid_db_credentials?(anything) { true }
      data_source.save!
      data_source.owner_account.should_not be_nil
    end
  end

  it_should_behave_like :data_source_with_access_control
  it_should_behave_like :data_source_with_db_name_port_validations

  describe "DataSource Integration", :oracle_integration do
    let(:data_source) { OracleIntegration.real_data_source }
    let(:account) { data_source.accounts.find_by_owner_id(data_source.owner.id) }

    it_should_behave_like :data_source_integration
  end

  describe ".type_name" do
    it "is DataSource" do
      subject.type_name.should == 'DataSource'
    end
  end

  it_behaves_like(:data_source_with_update) do
    let(:data_source) { data_sources(:oracle) }
  end

  describe "#schemas" do
    let(:new_oracle) { FactoryGirl.create(:oracle_data_source) }
    let(:schema) { OracleSchema.create!(:name => 'test_schema', :data_source => new_oracle) }

    it "includes schemas" do
      new_oracle.schemas.should include schema
    end
  end

  describe "#refresh_databases" do
    it "calls refresh_schemas" do
      options = {:foo => 'bar'}
      mock(data_source).refresh_schemas(options)
      data_source.refresh_databases(options)
    end
  end

  describe "#refresh_schemas" do
    let(:data_source) { data_sources(:oracle) }

    context "with stubbed out database" do
      before do
        stub(data_source).update_permission
      end

      it 'returns the schema names' do
        # schema names from fixture builder
        data_source.refresh_schemas.should =~ ["oracle", "oracle_empty"]
      end
    end

    context "with real oracle database", :oracle_integration do
      let(:data_source) { OracleIntegration.real_data_source }
      let(:schema) { OracleIntegration.real_schema }
      let(:account_with_access) { data_source.owner_account }

      before do
        stub(Schema).refresh { [schema] }
        stub(data_source.schemas).find { schema }
      end

      it 'calls Schema.refresh for each account' do
        schema.data_source_accounts = [account_with_access]
        mock(Schema).refresh(account_with_access, data_source, {:refresh_all => true}) { [schema] }
        data_source.refresh_schemas
      end

      it "adds new data source accounts to each Schema" do
        schema.data_source_accounts = []
        schema.data_source_accounts.find_by_id(account_with_access.id).should be_nil
        data_source.refresh_schemas
        schema.data_source_accounts.find_by_id(account_with_access.id).should == account_with_access
      end

      it "continues to next account when unable to connect with an account" do
        stub(data_source).accounts { [account_with_access, account_with_access] }
        mock(Schema).refresh.with_any_args.twice { raise OracleConnection::DatabaseError.new(:GENERIC) }
        expect{data_source.refresh_schemas}.not_to raise_error
      end

      it "enqueues a reindex_datasets worker for each schema if accounts were changed" do
        schema.data_source_accounts = []
        schema.data_source_accounts.find_by_id(account_with_access.id).should be_nil
        mock(SolrIndexer.SolrQC).enqueue_if_not_queued("OracleSchema.reindex_datasets", schema.id).once
        data_source.refresh_schemas
        data_source.refresh_schemas
      end
    end
  end
end