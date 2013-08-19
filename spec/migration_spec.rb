require_relative 'spec_helper'

describe "Migration" do

  before(:all) do
    verify_archon_dataset
    nuke_aspace

    e = Enumerator.new do |y|
      m = MigrationJob.new
      m.connection_check
      m.migrate(y)
    end

    e.each do |msg|
      puts msg
    end 

    JSONModel.set_repository(2)

    @r1 = find(:resource, 1, "resolve[]" => ['classification', 'linked_agents', 'subjects'])
  end

  def find(type, id, opts={})
    JSONModel::JSONModel(type).find(id, opts)
  end

  xit "can link a classification to a creator" do
    c = find(:classification, 2)
    c.title.should eq("ClassificationMgr.Title-Archon")
    c.creator.should_not be_nil
    c.creator['ref'].should eq('/agents/people/7')
  end


  it "builds a resource.id_* fields from the classifications linked to a collection" do
    @r1.id_0.should eq('01')
  end


  it "links a resource to a classification" do
    @r1.classification['_resolved']['title'].should eq("ClassificationMgr.Title-Archon")
  end


  it "maps ids in 'Creators' to linked_agents with type 'creator'" do
    link = @r1.linked_agents.find{|l| l['role'] == 'creator'}
    link['_resolved']['names'][0]['primary_name'].should eq('Creator.Corpname-Archon')
  end


  it "maps ids in 'Subjects' to linked subjects" do
    @r1.subjects.length.should eq(7)
  end
end
    


