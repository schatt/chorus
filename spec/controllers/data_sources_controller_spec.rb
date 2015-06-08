require 'spec_helper'

describe DataSourcesController do
  let(:user) { users(:owner) }

  before { log_in user }

  describe "index" do
    let(:permitted_data_source) { data_sources(:owners) }
    let(:prohibited_data_source) { data_sources(:admins) }
    let(:online_data_source) { data_sources(:online) }
    let(:offline_data_source) { data_sources(:offline) }

    it_behaves_like "a paginated list"
    it_behaves_like :succinct_list

    it "returns data sources that the user can access" do
      get :index
      response.code.should == "200"
      decoded_response.map(&:id).should include(online_data_source.id)
      decoded_response.map(&:id).should include(offline_data_source.id)
      decoded_response.map(&:id).should include(permitted_data_source.id)
      decoded_response.map(&:id).should_not include(prohibited_data_source.id)
    end

    context 'when all => "true" is passed' do
      it "returns all data sources" do
        get :index, :all => true
        response.code.should == "200"
        decoded_response.size.should == DataSource.count
        decoded_response.map(&:id).should include(online_data_source.id)
        decoded_response.map(&:id).should include(offline_data_source.id)
        decoded_response.map(&:id).should include(permitted_data_source.id)
        decoded_response.map(&:id).should include(prohibited_data_source.id)
      end
    end

    describe "filtering by type" do
      it "filters by gpdb data sources" do
        get :index, :entity_type => "gpdb_data_source", :all => true
        decoded_response.map(&:id).should =~ DataSource.where(:type => GpdbDataSource).pluck(:id)
      end

      it "filters by oracle data sources" do
        get :index, :entity_type => "oracle_data_source", :all => true
        decoded_response.map(&:id).should =~ DataSource.where(:type => OracleDataSource).pluck(:id)
      end

      it 'filters by jdbc data sources' do
        get :index, :entity_type => 'jdbc_data_source', :all => true
        decoded_response.map(&:id).should =~ DataSource.where(:type => JdbcDataSource).pluck(:id)
      end

      it 'filters by pg data sources' do
        get :index, :entity_type => 'pg_data_source', :all => true
        decoded_response.map(&:id).should =~ DataSource.where(:type => PgDataSource).pluck(:id)
      end

      it 'filters by multiple types' do
        get :index, :entity_type => %w(pg_data_source gpdb_data_source), :all => true
        decoded_response.map(&:id).should =~ DataSource.where(:type => %w(PgDataSource GpdbDataSource)).pluck(:id)
      end
    end
  end

  describe "show" do
    let(:data_source) { DataSource.first }

    context "with a valid data source id" do
      it "does not require authorization" do
        dont_allow(subject).authorize!.with_any_args
        get :show, :id => data_source.to_param
      end

      it "succeeds" do
        get :show, :id => data_source.to_param
        response.should be_success
      end

      it "presents the gpdb data source" do
        mock.proxy(controller).present(data_source)
        get :show, :id => data_source.to_param
      end
    end

    generate_fixture "gpdbDataSource.json" do
      get :show, :id => data_sources(:owners).to_param
    end

    generate_fixture "oracleDataSource.json" do
      get :show, :id => data_sources(:oracle).to_param
    end

    generate_fixture 'jdbcDataSource.json' do
      get :show, :id => data_sources(:jdbc).to_param
    end

    generate_fixture 'pgDataSource.json' do
      get :show, :id => data_sources(:postgres).to_param
    end

    context "with an invalid gpdb data source id" do
      it "returns not found" do
        get :show, :id => -1
        response.should be_not_found
      end
    end
  end

  describe "update" do
    let(:changed_attributes) { {} }
    let(:gpdb_data_source) { data_sources(:owners) }
    let(:params) do
      {
          :id => gpdb_data_source.id,
          :name => "changed"
      }
    end

    before do
      any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { true } }
    end

    it "uses authorization" do
      mock(subject).authorize!(:edit, gpdb_data_source)
      put :update, params
    end

    it "presents the gpdb data source" do
      mock.proxy(controller).present(gpdb_data_source)
      put :update, params
    end

    it "returns 200" do
      put :update, params
      response.code.should == "200"
    end

    it "returns 422 when the update parameters are invalid" do
      params[:name] = ''
      put :update, params
      response.code.should == "422"
    end
  end

  describe "create" do
    it_behaves_like "an action that requires authentication", :put, :update, :id => '-1'

    let(:valid_attributes) do
      {
          :name => 'create_spec_name',
          :port => 12345,
          :host => 'server.emc.com',
          :db_name => 'postgres',
          :description => 'old description',
          :db_username => 'bob',
          :db_password => 'secret',
          :entity_type => entity_type,
          :shared => false
      }
    end

    context 'for a GpdbDataSource' do
      let(:entity_type) { "gpdb_data_source" }

      before do
        any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { true } }
      end

      it 'creates the data source' do
        expect {
          post :create, valid_attributes
        }.to change(GpdbDataSource, :count).by(1)
        response.code.should == "201"
      end

      it 'presents the data source' do
        mock_present do |data_source|
          data_source.name == valid_attributes[:name]
        end
        post :create, valid_attributes
      end

      it 'schedules a job to refresh the data source' do
        stub(SolrIndexer.SolrQC).enqueue_if_not_queued(anything, anything)
        mock(SolrIndexer.SolrQC).enqueue_if_not_queued('DataSource.refresh', numeric, {'new' => true})
        post :create, :data_source => valid_attributes
      end

      context "with invalid attributes" do
        it "responds with validation errors" do
          valid_attributes.delete(:name)
          post :create, valid_attributes
          response.code.should == "422"
        end
      end
    end

    context 'for a PgDataSource' do
      let(:entity_type) { 'pg_data_source' }

      before do
        any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { true } }
      end

      it 'creates the data source' do
        expect {
          post :create, valid_attributes
        }.to change(PgDataSource, :count).by(1)
        response.code.should == '201'
      end

      it 'presents the data source' do
        mock_present do |data_source|
          data_source.name == valid_attributes[:name]
        end
        post :create, valid_attributes
      end

      it 'schedules a job to refresh the data source' do
        stub(SolrIndexer.SolrQC).enqueue_if_not_queued(anything, anything)
        mock(SolrIndexer.SolrQC).enqueue_if_not_queued('DataSource.refresh', numeric, {'new' => true})
        post :create, :data_source => valid_attributes
      end

      context 'with invalid attributes' do
        it 'responds with validation errors' do
          valid_attributes.delete(:name)
          post :create, valid_attributes
          response.code.should == '422'
        end
      end
    end

    context "for an OracleDataSource" do
      let(:entity_type) { "oracle_data_source" }

      context "with valid db credentials" do
        before do
          any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { true } }
          stub(ChorusConfig.instance).oracle_configured? { true }
        end

        it "creates a new OracleDataSource" do
          expect {
            post :create, valid_attributes
          }.to change(OracleDataSource, :count).by(1)
          response.code.should == "201"
        end

        it "presents the OracleDataSource" do
          mock_present do |data_source|
            data_source.name == valid_attributes[:name]
          end

          post :create, :data_source => valid_attributes
        end

        it "creates a private OracleDataSource by default" do
          mock_present do |data_source|
            data_source.should_not be_shared
          end
          post :create, valid_attributes
        end

        it "can create a shared OracleDataSource" do
          mock_present do |data_source|
            data_source.should be_shared
          end
          post :create, valid_attributes.merge(:shared => true)
        end
      end

      context "when oracle is not configured" do
        before do
          stub(ChorusConfig.instance).oracle_configured? { false }
        end

        it "should return an error" do
          post :create, valid_attributes
          response.code.should == "422"
          decoded_errors.record.should == "DATA_SOURCE_DRIVER_NOT_CONFIGURED"
          decoded_errors.data_source.should == 'Oracle'
        end
      end
    end

    context 'for a JdbcDataSource' do
      let(:entity_type) { 'jdbc_data_source' }
      before do
        any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { true } }
      end

      it 'creates a new jdbc data source' do
        expect {
          post :create, valid_attributes
        }.to change(JdbcDataSource, :count).by 1

        response.code.should == '201'
      end

      it 'presents the JdbcDataSource' do
        mock_present do |data_source|
          data_source.name == valid_attributes[:name]
        end

        post :create, :data_source => valid_attributes
      end

      it 'creates a private JdbcDataSource by default' do
        mock_present do |data_source|
          data_source.should_not be_shared
        end
        post :create, valid_attributes
      end

      it 'can create a shared JdbcDataSource' do
        mock_present do |data_source|
          data_source.should be_shared
        end
        post :create, valid_attributes.merge(:shared => true)
      end
    end

    context 'for an unknown entity type' do
      let(:entity_type) { '######' }

      it 'returns an error' do
        post :create, valid_attributes
        response.should be_unprocessable
        decoded_errors.fields.entity_type.should have_key :INVALID
      end
    end

    describe 'restrictions' do
      let(:entity_type) { 'gpdb_data_source' }
      before do
        log_in users(:the_collaborator)
        stub(ChorusConfig.instance).restrict_data_source_creation? { !creatable }
      end

      context 'when data source creation is restricted' do
        let(:creatable) { false }

        it 'forbids a non-admin user' do
          post :create, valid_attributes
          response.should be_forbidden
        end
      end

      context 'when data source creation is not restricted' do
        let(:creatable) { true }

        it 'allows a non-admin user' do
          post :create, valid_attributes
          response.should_not be_forbidden
        end
      end
    end
  end

  describe "destroy" do
    let(:data_source) { data_sources(:owners) }
    it "destroys the model" do
      delete :destroy, :id => data_source.id
      response.should be_success
      DataSource.find_by_id(data_source.id).should be_nil
    end

    it "uses authorization" do
      mock(subject).authorize! :edit, data_source
      delete :destroy, :id => data_source.id
    end
  end

  context 'in demo mode' do
    it_behaves_like 'a protected demo mode controller' do
      let(:gpdb_data_source) { data_sources(:owners) }
      let(:params) { { :id => gpdb_data_source.id, :name => 'changed'} }
    end
  end
end
