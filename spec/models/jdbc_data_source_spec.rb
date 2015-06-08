require 'spec_helper'

describe JdbcDataSource do
  let(:data_source) { data_sources(:jdbc) }

  describe 'validations' do
    it { should validate_presence_of(:host) }

    context 'when creating' do
      let(:data_source) { FactoryGirl.build(:jdbc_data_source) }
      it 'validates the owner account' do
        mock(data_source).owner_account { mock(FactoryGirl.build(:data_source_account)).valid? { true } }
        data_source.valid?
      end
    end
  end

  describe 'destroy' do
    it 'enqueues a destroy_schemas job' do
      mock(QC.default_queue).enqueue_if_not_queued('JdbcSchema.destroy_schemas', data_source.id)
      data_source.destroy
    end

    it 'removes itself from the execution location field of any workfiles it owns' do
      workfiles = data_source.workfile_execution_locations.all
      workfiles.length.should > 0

      expect {
        data_source.destroy
      }.to change { WorkfileExecutionLocation.where(execution_location_id: data_source.id, execution_location_type: data_source.class.base_class.name).count }.from(workfiles.length).to(0)
    end
  end

  it_should_behave_like :data_source_with_access_control

  describe '#schemas' do
    let(:new_jdbc) { FactoryGirl.create(:jdbc_data_source) }
    let(:schema) { JdbcSchema.create!(:name => 'test_schema', :data_source => new_jdbc) }

    it 'includes schemas' do
      new_jdbc.schemas.should include schema
    end
  end

  describe '#refresh_databases' do
    it 'calls refresh_schemas' do
      options = {:foo => 'bar'}
      mock(data_source).refresh_schemas(options)
      data_source.refresh_databases(options)
    end
  end

  describe '#refresh_schemas' do

    context 'with stubbed out database' do
      before do
        stub(data_source).update_permissions
        stub(data_source).update_schemas
      end

      it 'returns the schema names' do
        # schema names from fixture builder
        data_source.refresh_schemas.should =~ %w(jdbc jdbc_empty)
      end
    end

    context 'with a real jdbc database', :jdbc_integration do
      let(:data_source) { JdbcIntegration.real_data_source }
      let(:schema) { JdbcIntegration.real_schema }
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

      it 'adds new data source accounts to each Schema' do
        schema.data_source_accounts = []
        schema.data_source_accounts.find_by_id(account_with_access.id).should be_nil
        data_source.refresh_schemas
        schema.data_source_accounts.find_by_id(account_with_access.id).should == account_with_access
      end

      it 'continues to next account when unable to connect with an account' do
        stub(data_source).accounts { [account_with_access, account_with_access] }
        mock(Schema).refresh.with_any_args.twice { raise JdbcConnection::DatabaseError.new(:GENERIC) }
        expect{data_source.refresh_schemas}.not_to raise_error
      end

      it 'enqueues a reindex_datasets worker for each schema if accounts were changed' do
        schema.data_source_accounts = []
        schema.data_source_accounts.find_by_id(account_with_access.id).should be_nil
        mock(SolrIndexer.SolrQC).enqueue_if_not_queued('JdbcSchema.reindex_datasets', schema.id).once
        data_source.refresh_schemas
        data_source.refresh_schemas
      end
    end
  end

  describe '.type_name' do
    it 'is DataSource' do
      subject.type_name.should == 'DataSource'
    end
  end

  describe '.reindex_data_source' do
    before do
      stub(Sunspot).index.with_any_args
    end

    it 'reindexes itself' do
      mock(Sunspot).index(data_source)
      DataSource.reindex_data_source(data_source.id)
    end

    it 'should reindex all of its datasets' do
      mock(Sunspot).index(is_a(Dataset)).times(data_source.datasets.count)
      DataSource.reindex_data_source(data_source.id)
    end
  end
end