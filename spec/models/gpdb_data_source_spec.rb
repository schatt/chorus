require "spec_helper"

describe GpdbDataSource do
  describe "associations" do
    it { should have_many(:databases).class_name('GpdbDatabase') }
    it { should have_many(:schemas).through(:databases) }
    it { should have_many(:datasets).through(:schemas) }
  end

  describe "#create" do
    let(:user) { users(:admin) }
    let :valid_input_attributes do
      {
          :name => "create_spec_name",
          :port => 12345,
          :host => "server.emc.com",
          :db_name => "postgres",
          :description => "old description",
          :db_username => "bob",
          :db_password => "secret"
      }
    end

    before do
      any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { true } }
    end

    it "requires db username and password" do
      [:db_username, :db_password].each do |attribute|
        data_source = user.gpdb_data_sources.build(valid_input_attributes.merge(attribute => nil), :as => :create)
        data_source.should have_error_on(attribute)
      end
    end

    it "requires that a real connection to GPDB requires valid credentials" do
      any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { false } }
      data_source = user.gpdb_data_sources.build(valid_input_attributes, :as => :create)
      data_source.should have_error_on(:base).with_message(:INVALID_PASSWORD)
    end

    it "can save a new data_source that is shared" do
      data_source = user.gpdb_data_sources.create(valid_input_attributes.merge({:shared => true}), :as => :create)
      data_source.shared.should == true
      data_source.should be_valid
    end

    describe "validating hawq data sources" do
      let :valid_input_attributes do
        {
          :name => "create_spec_name",
          :port => 12345,
          :host => "server.emc.com",
          :db_name => "postgres",
          :description => "old description",
          :db_username => "bob",
          :db_password => "secret",
          :is_hawq => true
        }
      end

      before do
        any_instance_of(DataSource) { |ds| stub(ds).is_hawq_data_source? { false } }
      end

      it "must validate that it is, in fact, a hawq data source" do
        data_source = user.gpdb_data_sources.build(valid_input_attributes, :as => :create)
        data_source.should have_error_on(:base).with_message(:INVALID_HAWQ_DATA_SOURCE)
      end
    end
  end

  describe "#create_database" do
    let(:connection) { Object.new }
    let(:data_source) { data_sources(:default) }
    let(:user) { "hiya" }
    let(:database_name) { "things" }

    before do
      stub(data_source).connect_as(user) { connection }
      stub(data_source).refresh_databases { data_source.databases.create(:name => database_name) }
    end

    it "should create the database" do
      mock(connection).create_database(database_name)
      expect do
        data_source.create_database(database_name, user).name.should == database_name
      end.to change(GpdbDatabase, :count).by(1)
    end

    context "when the database is invalid" do
      before do
        any_instance_of(GpdbDatabase) do |database|
          stub(database).valid? { false }
        end
      end

      it "should not create a database" do
        dont_allow(connection).create_database.with_any_args
        expect do
          expect do
            data_source.create_database(database_name, user)
          end.to raise_error(ActiveRecord::RecordInvalid)
        end.not_to change(GpdbDatabase, :count)
      end
    end
  end

  it_behaves_like 'a data source with sandboxes' do
    let(:data_source) { FactoryGirl.create :gpdb_data_source }
    let(:database) { FactoryGirl.create(:gpdb_database, :data_source => data_source, :name => 'db') }
    let(:schema) { FactoryGirl.create(:gpdb_schema, :name => 'schema', :database => database) }
  end

  describe "#refresh_databases", :greenplum_integration do
    context "with database integration" do
      let(:account_with_access) { GreenplumIntegration.real_account }
      let(:gpdb_data_source) { account_with_access.data_source }
      let(:database) { GreenplumIntegration.real_database }

      it 'adds new database_data_source_accounts and enqueues a Database.reindex_datasets' do
        mock(SolrIndexer.SolrQC).enqueue_if_not_queued('Database.reindex_datasets', database.id)
        stub(SolrIndexer.SolrQC).enqueue_if_not_queued('Database.reindex_datasets', anything)
        database.data_source_accounts = []
        database.data_source_accounts.find_by_id(account_with_access.id).should be_nil
        gpdb_data_source.refresh_databases
        database.data_source_accounts.find_by_id(account_with_access.id).should == account_with_access
      end

      it 'does not enqueue Database.reindex_datasets if the data_source accounts for a database have not changed' do
        stub(SolrIndexer.SolrQC).enqueue_if_not_queued('Database.reindex_datasets', anything)
        dont_allow(SolrIndexer.SolrQC).enqueue_if_not_queued('Database.reindex_datasets', database.id)
        gpdb_data_source.refresh_databases
      end
    end

    context "with database stubbed" do
      let(:gpdb_data_source) { data_sources(:owners) }
      let(:database) { databases(:default) }
      let(:missing_database) { gpdb_data_source.databases.where("id <> #{database.id}").first }
      let(:account_with_access) { gpdb_data_source.owner_account }
      let(:account_without_access) { data_source_accounts(:unauthorized) }

      context "when database query is successful" do
        before do
          stub_gpdb(gpdb_data_source.owner_account, gpdb_data_source.send(:database_and_role_sql) => [
              {'database_name' => database.name, 'db_username' => account_with_access.db_username},
              {'database_name' => 'something_new', 'db_username' => account_with_access.db_username}
          ])
        end

        it "creates new databases" do
          gpdb_data_source.databases.where(:name => 'something_new').should_not exist
          gpdb_data_source.refresh_databases
          gpdb_data_source.databases.where(:name => 'something_new').should exist
        end

        it 'should not index databases that were just created' do
          stub(SolrIndexer.SolrQC).enqueue_if_not_queued('Database.reindex_datasets', anything) do |method, id|
            Database.find(id).name.should_not == 'something_new'
          end
          gpdb_data_source.refresh_databases
        end

        it "removes database_data_source_accounts if they no longer exist" do
          database.data_source_accounts << account_without_access
          gpdb_data_source.refresh_databases
          database.data_source_accounts.find_by_id(account_without_access.id).should be_nil
        end

        it "marks databases as stale if they no longer exist" do
          missing_database.should_not be_stale
          gpdb_data_source.refresh_databases(:mark_stale => true)
          missing_database.reload.should be_stale
          missing_database.stale_at.should be_within(5.seconds).of(Time.current)
        end

        it "does not mark databases as stale if flag not set" do
          missing_database.should_not be_stale
          gpdb_data_source.refresh_databases
          missing_database.reload.should_not be_stale
        end

        it "clears the stale flag on databases if they are found again" do
          database.mark_stale!
          gpdb_data_source.refresh_databases
          database.reload.should_not be_stale
        end

        it "does not update the stale_at time" do
          Timecop.freeze(1.year.ago) do
            missing_database.mark_stale!
          end
          gpdb_data_source.refresh_databases(:mark_stale => true)
          missing_database.reload.stale_at.should be_within(5.seconds).of(1.year.ago)
        end

        it "calls refresh_schemas" do
          options = {:foo => 'bar'}
          mock(gpdb_data_source).refresh_schemas(options)
          gpdb_data_source.refresh_databases options
        end

        it 'does not refresh schemas in stale databases' do
          missing_database.mark_stale!
          dont_allow(Schema).refresh(anything, missing_database, anything)
          mock(Schema).refresh(anything, database, anything)

          gpdb_data_source.refresh_schemas
        end
      end

      context "when the data_source is not available" do
        before do
          stub_gpdb_fail
        end

        it "marks all the associated databases as stale if the flag is set" do
          gpdb_data_source.refresh_databases(:mark_stale => true)
          database.reload.should be_stale
        end

        it "does not mark the associated databases as stale if the flag is not set" do
          gpdb_data_source.refresh_databases
          database.reload.should_not be_stale
        end
      end
    end
  end

  describe "#connect_with" do
    let(:data_source) { data_sources(:default) }
    let(:account) { data_source_accounts(:unauthorized) }

    it "should return a GreenplumConnection" do
      mock(GreenplumConnection).new(data_source, account, {
                                        :logger => Rails.logger
                                    }) { "this is my connection" }
      data_source.connect_with(account).should == "this is my connection"
    end
  end

  describe "#databases", :greenplum_integration do
    let(:account) { GreenplumIntegration.real_account }

    it "should not include the 'template0' database" do
      account.data_source.databases.map(&:name).should_not include "template0"
    end
  end

  describe "#destroy" do
    let(:data_source) { data_sources(:default) }
    before do
      any_instance_of(GreenplumConnection) do |connection|
        stub(connection).running?
      end
    end

    it "enqueues a destroy_databases job" do
      mock(QC.default_queue).enqueue_if_not_queued('Database.destroy_databases', data_source.id)
      data_source.destroy
    end

    it "cancels any source imports" do
      import = imports(:one)
      data_source = import.source.data_source

      import.success.should be_nil
      data_source.destroy
      import.reload.success.should == false
    end

    it "cancels any destination workspace imports" do
      import = imports(:one)
      source_dataset = datasets(:alternate)
      import.source = source_dataset
      import.save(:validate => false)
      data_source = import.workspace.sandbox.data_source

      import.success.should be_nil
      data_source.destroy
      import.reload.success.should == false
    end

    it "cancels any destination schema imports" do
      import = imports(:oracle)
      data_source = import.schema.data_source
      import.success.should be_nil
      data_source.destroy
      import.reload.success.should == false
    end
  end

  it_should_behave_like :data_source_with_access_control
  it_should_behave_like :data_source_with_db_name_port_validations

  it_behaves_like(:data_source_with_update) do
    let(:data_source) { data_sources(:default) }
  end

  describe "DataSource Integration", :greenplum_integration do
    let(:data_source) { GreenplumIntegration.real_data_source }
    let(:account) { data_source.accounts.find_by_owner_id(data_source.owner.id) }

    it_behaves_like :data_source_integration
  end
end
