require 'spec_helper'
require 'timecop'

describe Workspace do
  before do
    stub(Alpine::API).delete_work_flow.with_any_args

    [Import].each do |stuff|
      any_instance_of(stuff) do |import|
        stub(import).tables_have_consistent_schema { true }
        stub(import).table_exists? { true }
      end
    end
  end

  it_behaves_like "a notable model" do
    let!(:note) do
      Events::NoteOnWorkspace.create!({
                                          actor: users(:owner),
                                          workspace: model,
                                          body: "This is the body"
                                      }, as: :create)
    end

    let!(:model) { workspaces(:public_with_no_collaborators) }
  end

  describe "associations" do
    it { should have_many(:members) }
    it { should have_many(:activities) }
    it { should have_many(:events) }
    it { should belong_to(:sandbox) }
    it { should have_many(:owned_notes).class_name('Events::Base').conditions("events.action ILIKE 'Events::Note%'") }
    it { should have_many(:owned_events).class_name('Events::Base') }
    it { should have_many(:comments).through(:owned_events) }
  end

  describe "create" do
    let(:owner) { users(:no_collaborators) }
    let(:workspace) { owner.owned_workspaces.create!(name: 'new workspace!') }

    it "creates a membership for the owner" do
      workspace.members.should include(owner)
    end

    it "shows sandbox datasets by default" do
      workspace.show_sandbox_datasets.should be_true
    end
  end

  describe "validations" do
    let(:workspace) { workspaces(:public_with_no_collaborators) }
    let(:max_workspace_icon_size) { ChorusConfig.instance['file_sizes_mb']['workspace_icon'] }

    it { should validate_presence_of :name }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should validate_attachment_size(:image).less_than(max_workspace_icon_size.megabytes) }
    it { should validate_with MemberCountValidator }
  end

  describe ".active" do
    let(:active_workspace) { workspaces(:public_with_no_collaborators) }
    let(:archived_workspace) { workspaces(:archived) }

    it "returns only active workspaces" do
      workspaces = Workspace.active
      workspaces.should include(active_workspace)
      workspaces.should_not include(archived_workspace)
    end
  end

  describe ".workspaces_for" do
    context "user is admin" do
      let(:admin) { users(:admin) }
      it "returns unscoped workspaces" do
        mock(Workspace).scoped

        described_class.workspaces_for(admin)
      end
    end

    context "user is not admin" do
      let(:user) { users(:owner) }
      it "returns limited workspaces" do
        mock(Workspace).accessible_to(user)

        described_class.workspaces_for(user)
      end
    end
  end

  describe ".accessible_to" do
    let(:public_workspace) { workspaces(:public) }
    let(:owned_workspace) { workspaces(:private_with_no_collaborators) }
    let(:private_workspace) { workspaces(:private) }
    let(:private_workspace_with_membership) { workspaces(:private_with_no_collaborators) }
    let(:user) { users(:no_collaborators) }

    it "returns public workspaces" do
      Workspace.accessible_to(user).should include public_workspace
    end

    it "returns private workspaces with membership" do
      Workspace.accessible_to(user).should include private_workspace_with_membership
    end

    it "returns private owned workspaces" do
      Workspace.accessible_to(user).should include owned_workspace
    end

    it "does not return private workspaces" do
      Workspace.accessible_to(user).should_not include private_workspace
    end
  end

  describe "#members_accessible_to" do
    let(:private_workspace) { workspaces(:private_with_no_collaborators) }
    let(:workspace) { workspaces(:public_with_no_collaborators) }

    let(:owner) { users(:owner) }
    let(:user) { users(:no_collaborators) }
    let(:admin) { users(:admin) }

    context "public workspace" do
      it "returns all members" do
        workspace.members << owner

        members = workspace.members_accessible_to(user)
        members.should include(owner, user)
      end
    end

    context "user is a member of a private workspace" do
      it "returns all members" do
        private_workspace.members << owner

        members = private_workspace.members_accessible_to(owner)
        members.should include(owner, user)
      end
    end

    context "user is not a member of a private workspace" do
      it "returns nothing" do
        private_workspace.members_accessible_to(owner).should be_empty
      end
    end
  end

  describe "#datasets and #dataset_count" do
    let!(:schema) { FactoryGirl.create(:gpdb_schema) }
    let!(:other_schema) { FactoryGirl.create(:gpdb_schema) }
    let!(:sandbox_table) { FactoryGirl.create(:gpdb_table, schema: schema) }
    let!(:sandbox_view) { FactoryGirl.create(:gpdb_view, schema: schema) }
    let!(:source_table) { FactoryGirl.create(:gpdb_table, schema: other_schema) }
    let!(:other_table) { FactoryGirl.create(:gpdb_table, schema: other_schema) }
    let!(:hdfs_dataset) {
      FactoryGirl.create(:hdfs_dataset, name: "hdfs_dataset", file_mask: "/*", workspace: workspace)
    }
    let!(:chorus_view) {
      FactoryGirl.create(:chorus_view, name: "chorus_view", schema: schema, query: "select * from a_table", workspace: workspace)
    }
    let!(:chorus_view_from_source) {
      FactoryGirl.create(:chorus_view, name: "chorus_view_from_source", schema: other_schema, query: "select 1", workspace: workspace)
    }
    let(:user) { users(:the_collaborator) }

    context "when the workspace has a sandbox" do
      let!(:workspace) { FactoryGirl.create(:workspace, sandbox: schema) }

      before do
        workspace.source_datasets << source_table
      end

      context "when the user does not have a data source account" do
        it "lets them see associated datasets and chorus views only" do
          workspace.datasets(user).to_a.should =~ [source_table, chorus_view, chorus_view_from_source, hdfs_dataset]
          workspace.dataset_count(user).should == 4
        end
      end

      context "when the user has a data source account" do
        let!(:account) do
          FactoryGirl.build(:data_source_account, data_source: schema.database.data_source, owner: user).tap do |a|
            a.save(validate: false)
          end
        end

        context "and show_sandbox_datasets is false" do
          before do
            workspace.show_sandbox_datasets = false
            workspace.save
            stub(GpdbDataset).visible_to(account, schema, anything) {
              [sandbox_table, source_table, chorus_view, hdfs_dataset, sandbox_view, chorus_view_from_source]
            }
          end

          it "shows associated datasets and chorus views only" do
            workspace.datasets(user).to_a.should =~ [source_table, chorus_view, hdfs_dataset, chorus_view_from_source]
            workspace.dataset_count(user).should == 4
          end

          context "and a sandbox table is associated with the worldspace" do
            let(:jdbc_table) { datasets(:jdbc_table) }
            let(:oracle_table) { datasets(:oracle_table) }

            before do
              workspace.source_datasets << jdbc_table
              workspace.source_datasets << oracle_table
              workspace.source_datasets << sandbox_table
            end

            it "shows all source tables / chorus views excluding the sandbox table and jdbc table when asking for source tables" do
              workspace.datasets(user, {entity_subtype: 'SOURCE_TABLE', all_import_sources: true}).to_a.should =~ [source_table, chorus_view, chorus_view_from_source, oracle_table]
              workspace.dataset_count(user, {entity_subtype: 'SOURCE_TABLE', all_import_sources: true}).should == 4
            end
          end

          context "and 'all import destinations' is passed" do
            it "shows all sandbox datasets" do
              stub(GpdbDataset).visible_to(account, schema, anything) {
                workspace.sandbox.datasets
              }
              workspace.datasets(user, {:all_import_destinations => true}).to_a.should =~ workspace.sandbox.datasets
            end
          end
        end

        context "when connecting fails due to invalid credentials" do
          before do
            mock(schema).dataset_count(anything, anything) { raise DataSourceConnection::InvalidCredentials.new(Object.new) }
            mock(GpdbDataset).visible_to(anything, schema, anything) { raise DataSourceConnection::InvalidCredentials.new(Object.new) }
          end

          it "lets them see associated datasets and chorus views only" do
            workspace.datasets(user).to_a.should =~ [source_table, chorus_view, chorus_view_from_source, hdfs_dataset]
            workspace.dataset_count(user).should == 4
          end
        end

        context "when the sandbox has tables" do
          let(:magic_number) { 142 }
          before do
            stub(GpdbDataset).visible_to(account, schema, anything) { [sandbox_table, sandbox_view] }
            stub(schema).dataset_count(account, anything) { magic_number }
          end

          it "includes datasets in the workspace's sandbox and all of its source datasets" do
            workspace.datasets(user).to_a.should =~ [sandbox_table, source_table, chorus_view, sandbox_view, chorus_view_from_source, hdfs_dataset]
            workspace.dataset_count(user).should == 1 + 2 + 1 + magic_number
          end

          it "filters by entity_subtype" do
            workspace.datasets(user, {:entity_subtype => "SANDBOX_DATASET"}).to_a.should =~ [sandbox_table, sandbox_view]
            workspace.dataset_count(user, {:entity_subtype => "SANDBOX_DATASET"}).should == magic_number
            workspace.datasets(user, {:entity_subtype => "CHORUS_VIEW"}).to_a.should =~ [chorus_view, chorus_view_from_source]
            workspace.dataset_count(user, {:entity_subtype => "CHORUS_VIEW"}).should == 2
            workspace.datasets(user, {:entity_subtype => "SOURCE_TABLE"}).to_a.should =~ [source_table]
            workspace.datasets(user, {:entity_subtype => "NON_CHORUS_VIEW"}).to_a.should =~ [sandbox_table, sandbox_view, source_table]
            workspace.dataset_count(user, {:entity_subtype => "SOURCE_TABLE"}).should == 1
          end

          describe "filtering by sandbox table" do
            before do
              options ={entity_subtype: "SANDBOX_TABLE",
                        tables_only: true}
              mock(GpdbDataset).visible_to(account, schema, options) {
                [sandbox_table]
              }
              stub(schema).dataset_count(account, options) { 141 }

            end

            it "filters out views" do
              workspace.datasets(user, {entity_subtype: "SANDBOX_TABLE"}).to_a.should =~ [sandbox_table]
              workspace.dataset_count(user, {entity_subtype: "SANDBOX_TABLE"}).should == 141
            end
          end
        end

        context "when there are no datasets for this workspace" do
          before do
            stub(GpdbDataset).visible_to(account, schema, anything) { [] }
            stub(schema).dataset_count(account, anything) { 0 }
          end

          it "returns no results" do
            workspace.datasets(user, {:entity_subtype => "SANDBOX_TABLE"}).should =~ []
            workspace.datasets(user, {:entity_subtype => "SANDBOX_DATASET"}).should =~ []
            workspace.dataset_count(user, {:entity_subtype => "SANDBOX_DATASET"}).should == 0
          end
        end
      end

      context "with associated datasets and options contain a database id" do
        let!(:chorus_view) { FactoryGirl.create(:chorus_view, :workspace => workspace, :schema => dataset1.schema) }
        let(:dataset1) { datasets(:default_table) }
        let(:dataset2) { datasets(:searchquery_table) }

        before do
          workspace.source_datasets << dataset1
          workspace.source_datasets << dataset2
        end

        it "filters the datasets to specified database" do
          workspace_datasets = workspace.datasets(user, {:database_id => dataset1.schema.database.id})
          workspace_datasets.should include(dataset1)
          workspace_datasets.should include(chorus_view)
          workspace_datasets.should_not include(hdfs_dataset)
          workspace_datasets.should_not include(dataset2)
        end
      end
    end

    context "when the workspace does not have a sandbox" do
      let!(:workspace) { FactoryGirl.create(:workspace, sandbox: nil) }
      let!(:chorus_view) {
        FactoryGirl.create(:chorus_view,
                           name: "chorus_view",
                           query: "select 1",
                           schema: schema,
                           workspace: workspace)
      }

      before do
        workspace.source_datasets << source_table
      end

      it "includes the workspace's bound datasets" do
        workspace.datasets(user).to_a.should include(source_table)
      end

      it "includes the workspace's chorus views" do
        workspace.datasets(user).to_a.should include(chorus_view)
      end

      it "includes the workspace's hdfs datasets" do
        workspace.datasets(user).to_a.should include(hdfs_dataset)
      end

      context 'when the workspace has associated datasets' do
        let!(:chorus_view) { FactoryGirl.create(:chorus_view, :workspace => workspace, :schema => dataset1.schema) }
        let(:dataset1) { datasets(:default_table) }
        let(:dataset2) { datasets(:searchquery_table) }

        before do
          workspace.source_datasets << dataset1
          workspace.source_datasets << dataset2
        end

        context 'and a database id is given' do
          it 'filters for the given database' do
            workspace.datasets(user, {:database_id => dataset1.schema.database.id}).should =~ [dataset1, chorus_view]
          end
        end

        context 'and filtering for SOURCE_TABLE' do
          let(:jdbc_table) { datasets(:jdbc_table) }
          let(:oracle_table) { datasets(:oracle_table) }

          before do
            workspace.source_datasets << jdbc_table
            workspace.source_datasets << oracle_table
          end

          it 'includes the source datasets' do
            datasets = workspace.datasets(user, {:entity_subtype => 'SOURCE_TABLE'})
            datasets.map(&:id).should =~ [source_table, dataset1, dataset2, jdbc_table, oracle_table].map(&:id)
          end

          context 'scoped to import sources' do
            it 'does not include jdbc but does include oracle' do
              datasets = workspace.datasets(user, {:entity_subtype => 'SOURCE_TABLE', :all_import_sources => true})
              datasets.map(&:id).should =~ [source_table, chorus_view, chorus_view_from_source, dataset1, dataset2, oracle_table].map(&:id)
            end
          end
        end
      end
    end

    context "when the workspace has no sandbox and no associated datasets" do
      let!(:workspace) { FactoryGirl.create(:workspace, :sandbox => nil) }

      before do
        workspace.associated_datasets.destroy_all
        workspace.directly_associated_datasets.destroy_all
      end

      it "returns an empty relation" do
        workspace.reload.datasets(user).should == []
      end
    end
  end

  describe "#image" do
    it { should have_attached_file(:image) }

    it "should have a nil image instead of a default missing image" do
      workspace = workspaces(:public_with_no_collaborators)
      workspace.update_attributes!(:image => nil)
      workspace.image.url.should == ""
    end
  end

  describe 'permissions_for' do
    it 'should have the correct permissions per user' do
      owner = users(:no_collaborators)
      private_workspace = workspaces(:private_with_no_collaborators)
      public_workspace = workspaces(:public_with_no_collaborators)
      member = users(:the_collaborator)
      admin = users(:admin)
      anon = users(:owner)
      dev = FactoryGirl.create(:user, :developer => true)
      private_workspace.members << dev
      admin_dev = FactoryGirl.create(:user, :developer => true, :admin => true)
      private_workspace.members << admin_dev
      public_admin_dev_member = workspaces(:public)
      public_admin_dev_member.members << admin_dev

      [
          [private_workspace, owner, [:admin]],
          [private_workspace, member, [:read, :commenting, :update, :duplicate_chorus_view]],
          [private_workspace, admin, [:admin]],
          [private_workspace, anon, []],
          [public_workspace, anon, [:read, :commenting]],
          [private_workspace, dev, [:read, :commenting, :update, :duplicate_chorus_view, :create_workflow]],
          [public_workspace, dev, [:read, :commenting]],
          [private_workspace, admin_dev, [:admin, :create_workflow]],
          [public_workspace, admin_dev, [:admin]],
          [public_admin_dev_member, admin_dev, [:admin, :create_workflow]]
      ].each do |workspace, user, list|
        workspace.permissions_for(user).should == list
      end
    end
  end

  describe "#archived?" do
    let(:active_workspace) { workspaces(:public_with_no_collaborators) }
    let(:archived_workspace) { workspaces(:archived) }

    it "says that active workspace is not archived" do
      active_workspace.should_not be_archived
    end

    it "says active workspace is not archived" do
      archived_workspace.should be_archived
    end
  end

  describe "#destroy" do
    let(:workspace) { workspaces(:public) }
    let!(:workfile) { FactoryGirl.create(:workfile, workspace: workspace) }

    it 'does not reindex the workspace' do
      any_instance_of(Workspace) { |data_source| dont_allow(data_source).solr_reindex }
      workspace.destroy
    end

    it "soft-deletes the associated workfiles" do
      workspace.destroy
      workfile.reload
      workfile.deleted_at.should_not be_nil
    end

    it "soft deletes associated chorus views" do
      chorus_views = workspace.chorus_views
      chorus_views.length.should > 0

      workspace.destroy
      chorus_views.each { |cv| cv.reload.deleted_at.should_not be_nil }
    end

    it "soft deletes associations to source datasets" do
      expect {
        workspace.destroy
      }.to change { AssociatedDataset.where(:workspace_id => workspace.id).count }.to(0)
      AssociatedDataset.unscoped.where(:workspace_id => workspace.id).should_not be_empty
    end
  end

  describe "#reindex_workspace" do
    let(:workspace) { workspaces(:public) }

    before do
      stub(Sunspot).index.with_any_args
    end

    it "reindexes itself" do
      mock(Sunspot).index(workspace)
      Workspace.reindex_workspace(workspace.id)
    end

    it "reindexes the workfiles" do
      mock(Sunspot).index(is_a(Workfile)).times(workspace.workfiles.count)
      Workspace.reindex_workspace(workspace.id)
    end

    it "should reindex notes in the workspace" do
      mock(Sunspot).index(is_a(Events::Note)).times(workspace.owned_notes.count)
      Workspace.reindex_workspace(workspace.id)
    end

    it "should reindex comments in the workspace" do
      mock(Sunspot).index(is_a(Comment)).times(workspace.comments.count)
      Workspace.reindex_workspace(workspace.id)
    end
  end

  describe "#solr_reindex_later" do
    let(:workspace) { workspaces(:public) }
    it "should enqueue a job" do
      mock(SolrIndexer.SolrQC).enqueue_if_not_queued("Workspace.reindex_workspace", workspace.id)
      workspace.solr_reindex_later
    end
  end

  describe "#has_dataset" do
    let(:workspace) { workspaces(:public_with_no_collaborators) }
    let(:dataset) { FactoryGirl.create(:gpdb_table) }

    context "when the workspace automatically adds sandbox tables" do
      before do
        workspace.show_sandbox_datasets = true
      end
      it "returns true if the dataset is in the workspace's sandbox" do
        workspace.sandbox = dataset.schema
        workspace.has_dataset?(dataset).should be_true
      end

      it "returns true if the dataset has already been associated with the workspace" do
        workspace.source_datasets << dataset
        workspace.has_dataset?(dataset).should be_true
      end
    end

    context "when the workspace does not automatically add sandbox tables" do
      before do
        workspace.show_sandbox_datasets = false
      end
      it "returns true if the dataset is in the workspace's sandbox" do
        workspace.sandbox = dataset.schema
        workspace.has_dataset?(dataset).should be_false
      end

      it "returns true if the dataset has already been associated with the workspace" do
        workspace.source_datasets << dataset
        workspace.has_dataset?(dataset).should be_true
      end
    end

    it "returns false otherwise" do
      workspace.has_dataset?(dataset).should be_false
    end
  end

  describe "search fields" do
    it "indexes text fields" do
      Workspace.should have_searchable_field :name
      Workspace.should have_searchable_field :summary
    end
  end

  describe "#member?" do
    it "is true for members" do
      workspaces(:public).member?(users(:owner)).should be_true
    end

    it "is false for non members" do
      workspaces(:public).member?(users(:no_collaborators)).should be_false
    end
  end

  describe "#archived=" do
    context "when setting to true" do
      let(:workspace) { workspaces(:public) }
      let(:archiver) { users(:owner) }

      it "sets the archived_at timestamp" do
        workspace.update_attributes!(:archiver => archiver, :archived => true)
        workspace.archived_at.should be_within(1.minute).of(Time.current)
      end

      it "has a validation error when archiver is not set" do
        workspace.update_attributes(:archived => true)
        workspace.should have(1).error_on(:archived)
      end
    end

    context "when setting to false" do
      let(:workspace) { workspaces(:archived) }
      it "clears the archived_at timestamp and archiver" do
        workspace.update_attributes(:archived => false)
        workspace.archived_at.should be_nil
        workspace.archiver.should be_nil
      end
    end
  end

  describe "#associate_datasets" do
    let(:workspace) { workspaces(:public) }
    let(:dataset1) { datasets(:other_table) }
    let(:dataset2) { datasets(:other_view) }
    let(:user) { workspace.owner }
    it "should associate multiple datasets with itself" do
      workspace.has_dataset?(dataset1).should be_false
      workspace.has_dataset?(dataset2).should be_false
      workspace.associate_datasets(user, [dataset1, dataset2])
      workspace.source_datasets.include?(dataset1).should be_true
      workspace.source_datasets.include?(dataset2).should be_true
    end

    it "should raise an error when the dataset is already associated with a workspace" do
      workspace.associate_datasets(user, [dataset1])
      expect { workspace.associate_datasets(user, [dataset1]) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should create event and activity when associated" do
      expect {
        workspace.associate_datasets(user, [dataset1, dataset2])
      }.to change(Events::SourceTableCreated.by(user), :count).by(2)
    end
  end

  describe "callbacks" do
    let(:workspace) { workspaces(:public_with_no_collaborators) }
    let(:sandbox) { schemas(:default) }

    describe "before_save" do
      describe "update_has_added_sandbox" do
        it "sets if passed a valid sandbox_id" do
          workspace.sandbox_id = sandbox.id
          workspace.save!
          workspace.should have_added_sandbox
        end

        it "does not set it if passed an invalid sandbox_id" do
          workspace.sandbox_id = 8675309
          workspace.save
          workspace.should_not have_added_sandbox
        end

        it "does not unset it if sandbox is removed" do
          workspace = workspaces(:public)
          workspace.sandbox_id = nil
          workspace.save!
          workspace.should have_added_sandbox
        end
      end
    end

    describe "before_update" do
      describe "remove_source_datasets_on_sandbox_addition" do
        let(:sandbox_dataset) { datasets(:tagged) }
        let(:other_dataset) { datasets(:other_table) }

        before do
          workspace.source_datasets << sandbox_dataset
          workspace.source_datasets << other_dataset
          workspace.sandbox_id = sandbox.id
        end

        it "removes duplicate datasets" do
          workspace.save!
          workspace.source_datasets.should_not include(sandbox_dataset)
          sandbox_dataset.reload.should_not be_nil
        end

        it "does not remove datasets from other schemas" do
          workspace.save!
          workspace.source_datasets.should include(other_dataset)
        end

        it "does not remove source datasets if show_sandbox_datasets is false" do
          workspace.show_sandbox_datasets = false
          workspace.save!
          workspace.source_datasets.should include(sandbox_dataset)
        end
      end
    end

    describe "after_update" do
      let(:owner) { users(:no_collaborators) }

      before do
        set_current_user(owner)
      end

      it "creates an event if the workspace name was changed" do
        old_name = workspace.name
        expect {
          workspace.name = "new_workspace_name"
          workspace.save
        }.to change { Events::WorkspaceChangeName.count }.by(1)
        workspace.reload.name.should == 'new_workspace_name'
        Events::WorkspaceChangeName.last.additional_data.should == {'workspace_old_name' => old_name}
      end

      it "does not create an event if the workspace name was not changed" do
        expect {
          workspace.name = workspace.name
          workspace.save
        }.not_to change { Events::WorkspaceChangeName.count }
      end

      it "should not reindex" do
        dont_allow(workspace).solr_reindex_later
        workspace.update_attributes(:name => "foo")
      end

      describe "making the workspace private" do
        it "should reindex" do
          mock(workspace).solr_reindex_later
          workspace.update_attributes(:public => false)
        end
      end

      describe "making the workspace public" do
        let(:workspace) { workspaces(:private_with_no_collaborators) }
        it "should reindex" do
          mock(workspace).solr_reindex_later
          workspace.update_attributes(:public => true)
        end
      end
    end
  end

  describe "changing 'show sandbox datasets'" do
    let(:workspace) { workspaces(:public) }
    let(:schema_id) { workspace.sandbox.id }

    it 'enqueue a reindex of the sandbox' do
      mock(SolrIndexer.SolrQC).enqueue_if_not_queued("Schema.reindex_datasets", schema_id)
      workspace.show_sandbox_datasets = !workspace.show_sandbox_datasets
      workspace.save!
    end

    it 'does not do that by accident' do
      stub(SolrIndexer.SolrQC).enqueue_if_not_queued.with_any_args
      dont_allow(SolrIndexer.SolrQC).enqueue_if_not_queued("Schema.reindex_datasets", anything)
      workspace.toggle(:public)
      workspace.save!
    end

    it "should unassociate datasets in the sandbox" do
      workspace.show_sandbox_datasets = false
      workspace.save!
      dataset = Dataset.where(:schema_id => schema_id, :type => 'GpdbTable').first
      workspace.associate_datasets(workspace.owner, [dataset])
      workspace.reload.has_dataset?(dataset).should be_true
      workspace.show_sandbox_datasets = true
      workspace.save!
      workspace.source_datasets.should_not include(dataset)
      workspace.reload.has_dataset?(dataset).should be_true
      workspace.show_sandbox_datasets = false
      workspace.save!
      workspace.reload.has_dataset?(dataset).should be_false
    end
  end

  describe "milestones" do
    let(:workspace) { workspaces(:public) }

    describe "#milestones_count" do
      it "counts the total number of milestones" do
        workspace.milestones_count.should == 3
      end
    end

    describe "#milestones_achieved_count" do
      before do
        workspace.milestones.first.update_attributes(:state => 'achieved')
      end

      it "counts the milestones in achieved state" do
        workspace.reload.milestones_achieved_count.should == 1
      end
    end
  end

  it_should_behave_like "taggable models", [:workspaces, :public]

  it_behaves_like 'a soft deletable model' do
    let(:model) { workspaces(:public) }
  end
end
