require 'spec_helper'

describe Tag do
  describe "validation" do
    describe "length of name" do
      it "must be between 1 and 100" do
        Tag.new(:name => "").should_not be_valid
        Tag.new(:name => "A"*101).should_not be_valid

        Tag.new(:name => "A").should be_valid
        Tag.new(:name => "A"*100).should be_valid
      end
    end

    describe "uniqueness of name" do
      before do
        Tag.create!(:name => "unique-name")
      end
      it "requires a unique name to be valid" do
        Tag.new(:name => "unique-name").should_not be_valid
      end

      it "is case-insensitive" do
        Tag.new(:name => "UNIQUE-NAME").should_not be_valid
      end

      describe "database-level constraints" do
        it "raises an exception when name is in use" do
          expect {
            Tag.new(:name => "unique-name").save!(:validate => false)
          }.to raise_error(ActiveRecord::RecordNotUnique)
        end

        it "has a case-insensitive constraint" do
          expect {
            Tag.new(:name => "UNIQUE-NAME").save!(:validate => false)
          }.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end
    end

    it "does not allow commas" do
      tag = Tag.create(:name => "flower, tree")
      tag.should have_error_on(:name)
    end
  end

  describe "polymorphism" do
    it "can belong to multiple types" do
      table = FactoryGirl.create(:gpdb_table)
      table.tags << Tag.new(:name => "fancy tag")
      table.reload.tags.last.name.should == "fancy tag"

      view = FactoryGirl.create(:gpdb_view)
      view.tags << Tag.new(:name => "different tag")
      view.reload.tags.last.name.should == "different tag"
    end
  end

  describe "search fields" do
    it "indexes the tag name" do
      Tag.should have_searchable_field :name
    end
  end

  describe ".find_or_create_by_tag_name" do
    context "when the tag exists" do
      let!(:tag) { Tag.create!(:name => "ABC") }

      it "returns the tag" do
        Tag.find_or_create_by_tag_name("abc").should == tag
      end
    end

    context "when the tag does not exist" do
      it "creates a new tag" do
        -> {
          Tag.find_or_create_by_tag_name("abc")
        }.should change(Tag, :count).by(1)
      end

      it "returns the new tag" do
        tag = Tag.find_or_create_by_tag_name("abc")
        tag.name.should == "abc"
      end
    end
  end

  describe "#named_like" do
    it "returns tags based on substring match" do
      Tag.create!(:name => "abc")
      Tag.create!(:name => "ABD")
      Tag.create!(:name => "abe")
      Tag.create!(:name => "xyz")

      matching_tags = Tag.named_like("ab")

      matching_tags.map(&:name).should =~ ["abc", "ABD", "abe"]
    end

    it "is not vulnerable to sql injection" do
      Tag.named_like("'drop tables").to_sql.should match /\(name ILIKE '%''drop tables%'\)/
    end
  end

  describe "counter cache" do
    let(:tag) { Tag.create!(:name => "foobar") }
    let(:model_1) { workfiles(:public) }
    let(:model_2) { workspaces(:public) }

    it "knows how many taggings it has" do
      expect do
        model_1.tags << tag
        model_2.tags << tag
      end.to change { tag.reload.taggings_count }.by(2)
    end

    it "updates the taggings count when removing taggings"  do
      model_1.tags << tag
      model_2.tags << tag
      expect do
        model_1.tags.delete(tag)
        model_1.taggings.count.should == 0
      end.to change { tag.reload.taggings_count}.to(1)
    end

    it "resets the tag count" do
      model_1.tags << tag
      model_2.tags << tag

      tag.reload.update_attribute(:taggings_count, 0)

      expect { Tag.reset_all_counters }.to change { tag.reload.taggings_count }.to(2)
    end
  end

  describe "reindexing tagged objects" do
    let(:tag) { Tag.create!(name: "foo-tag-clan") }
    let(:model_1) { workfiles(:public) }
    let(:model_2) { workspaces(:public) }
    let(:job_args) { [
        [model_1.class.to_s, model_1.id],
        [model_2.class.to_s, model_2.id],
    ] }

    before do
      model_1.tags << tag
      model_2.tags << tag
    end

    it "should not reindex tagged objects after create" do
      dont_allow(SolrIndexer.SolrQC).enqueue_if_not_queued("SolrIndexer.reindex_objects", anything)
      Tag.create!(name: "another-tag")
    end

    it "should reindex tagged objects after update" do
      mock(SolrIndexer.SolrQC).enqueue_if_not_queued.with_any_args do |*args|
        args[0].should == "SolrIndexer.reindex_objects"
        args[1].should =~ job_args
      end
      tag.name = "new-tag-clan"
      tag.save!
    end

    it "should reindex tagged objects after destroy" do
      mock(SolrIndexer.SolrQC).enqueue_if_not_queued.with_any_args do |*args|
        args[0].should == "SolrIndexer.reindex_objects"
        args[1].should =~ job_args
      end
      tag.destroy
    end
  end
end
