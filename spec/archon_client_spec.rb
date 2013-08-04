require_relative 'spec_helper'

describe "Archon Client" do
  before(:all) do 
    client = get_archon_client

    pending "an instance of Archon to run the test against" unless client
  end


  it "can iterate over subject records" do
    limit = 20
    ids = []
    Archon.record_type(:subject).each do |s|
      ids << s["ID"]
      limit = limit-1
      break if limit < 1
    end

    ids.uniq.should eq(ids)
    (ids.count > 0).should be_true
  end
end
