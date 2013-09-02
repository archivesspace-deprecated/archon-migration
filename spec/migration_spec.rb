require_relative 'spec_helper'

describe "Migration" do

  before(:all) do
    verify_archon_dataset
    nuke_aspace

    e = Enumerator.new do |y|
      m = MigrationJob.new
      m.migrate(y)
    end

    @msgs = []

    e.each do |msg|
      puts msg
      @msgs << JSON.parse(msg.sub(/---\n/, ""))
    end 

    JSONModel.set_repository(2)

    @r1 = find(:resource, 1, "resolve[]" => ['classification', 'linked_agents', 'subjects'])


    @a1 = find(:accession, 1, "resolve[]" => ['classification', 'linked_agents', 'subjects'])

    @d1 = find(:digital_object, 1, "resolve[]" => ['linked_agents', 'subjects'])

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


  it "migrates the sample data without generating errors" do
    @msgs.map{|msg| msg['type']}.should_not include('error')
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


  it "maps Accession:'Donor' to a linked_agents" do
    link = @a1.linked_agents.find{|l| l['role'] == 'source'}
    link['_resolved']['names'][0]['primary_name'].should eq("AccessionsMgr.Donor-Archon")
    link['_resolved']['agent_contacts'][0]['name'].should eq("AccessionsMgr.Donor-Archon")
  end


  it "maps ids in Accession:Subjects to linked subjects" do
    @a1.subjects.length.should eq(7)
  end


  it "maps ids in 'Creators' to linked_agents with type 'creator'" do
    link = @a1.linked_agents.find{|l| l['role'] == 'creator'}
    link['_resolved']['names'][0]['primary_name'].should eq('Creator.Corpname-Archon')
  end


  it "links an accession to a classification" do
    @a1.classification['_resolved']['title'].should eq("ClassificationMgr.Title-Archon")
  end


  it "links Content-derived instances to Content-derived archival_objects" do
    aa = find(:archival_object, 2)
    aa.instances.count.should eq(1)
  end


  it "maps ids in Content:Subjects to linked subjects" do
    ao = find(:archival_object, 1)
    ao.subjects.length.should eq(7)
  end


  it "maps ids in DigitalContent:Subjects to linked subjects" do
    @d1.subjects.length.should eq(7)
  end


  it "maps digital_object records into archival_object instance subrecords" do
    ao = find(:archival_object, 1)
    diginst = ao.instances.find {|i| i['instance_type'] == 'digital_object'}
    diginst.should_not be_nil
  end


  it "maps digital_object records into resource instance subrecords" do
    r = find(:resource, 1)
    diginst = r.instances.find {|i| i['instance_type'] == 'digital_object'}
    diginst.should_not be_nil
  end


  it "maps DigitalFile records to digital_object_component and links them" do
    digital_object_component = find(:digital_object_component, 1)
    digital_object = find(:digital_object, 1)
    digital_object_component.digital_object['ref'].should eq(digital_object.uri)
  end


  it "links locations to accessions in its roundabout way" do
    accession = find(:accession, 1)
    location = find(:location, 1)

    ref = accession.instances[0]['container']['container_locations'][0]['ref']
    ref.should eq(location.uri)
  end


  it "maps Creator['BiogHist'] to agent.notes[].subnotes[0]['content']" do
    agent = find(:agent_person, 6)
    agent.notes[0]['subnotes'][0]['content'].should eq('BiogHist Note for Creator.')
  end
end
    


