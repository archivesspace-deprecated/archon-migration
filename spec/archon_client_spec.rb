require_relative 'spec_helper'

describe "Archon Client" do
  before(:all) do 
    client = get_archon_client
    if client
      repo = client.get_json('/?p=core/repositories&batch_start=1')
      unless repo['1']['Name'] == "Archon Migration Tracer"
        pending "an Archon instance running against the archon_tracer database"
      end
    else
      pending "an instance of Archon to run the test against"
    end
  end


  def test_iterate(rec_type, count)
    ids = []
    Archon.record_type(rec_type).each do |s|
      ids << s["ID"]
    end

    ids.uniq.should eq(ids)
    ids.count.should eq(count)
  end


  it "can iterate over subject records" do
    test_iterate(:subject, 13)
  end


  it "can find a subject record by ID" do
    s = Archon.record_type(:subject).find("2")
    s.has_key?("ID").should eq("2")
  end


  it "can iterate over user records" do
    test_iterate(:user, 4)
  end
end
