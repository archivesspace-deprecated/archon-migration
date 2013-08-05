require_relative 'spec_helper'

describe "Archon Client" do
  before(:all) do 
    client = get_archon_client

    pending "an instance of Archon to run the test against" unless client

    repo = client.get_json('/?p=core/repositories&batch_start=1')
    repo_name = repo['1']['Name']

    unless repo_name == "Archon Migration Tracer"
      pending "an Archon instance running against the archon_tracer database" 
    end
  end


  it "can iterate over subject records" do
    ids = []
    Archon.record_type(:subject).each do |s|
      ids << s["ID"]
    end

    ids.uniq.should eq(ids)
    ids.count.should eq(13)
  end

  
  it "can find a subject record by ID" do
    s = Archon.record_type(:subject).find("2")
    s.has_key?("ID").should eq("2")
  end
end
