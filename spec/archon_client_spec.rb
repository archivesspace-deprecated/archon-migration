require_relative 'spec_helper'

describe "Archon Client" do
  before(:all) do 
    @client = get_archon_client
    verify_archon_dataset(@client)
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


  it "can iterate over digital object records" do
    test_iterate(:digitalcontent, 1)
  end


  it "can iterate over digital file records" do
    test_iterate(:digitalfile, 1)
  end


  it "can fetch a digital file bitstream" do
    df = Archon.record_type(:digitalfile)
    bitstream = @client.get_bitstream('/?p=core/digitalfileblob&fileid=1')
    bitstream[0,4].should eq("\xff\xd8\xff\xe0")
  end
end
