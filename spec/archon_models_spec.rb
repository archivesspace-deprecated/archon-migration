require_relative 'spec_helper'

describe "Archon record mappings" do


  describe "Repository" do
    before :all do
      data = Hash[%w(ID Name Code Address Address2 City State ZIPCode ZIPPlusFour Phone PhoneExtension Fax Email EmailSignature CountryID).map {|field| [field, rand(36**4).to_s(36)]}]
      data["URL"] = "http://example.com"


      @rec = Archon.record_type(:repository).new(data)

      @obj = @rec.class.transform(@rec)
    end


    it "maps 'Name' to 'name'" do
      @obj.repository['name'].should eq(@rec["Name"])
    end


    it "maps 'Code' to 'org_code'" do
      @obj.repository['org_code'].should eq(@rec["Code"])
    end


    it "maps 'Address' to 'repository_with_agent.agent_representation.agent_contacts[0].address_1" do
      @obj.agent_representation['agent_contacts'][0]['address_1'].should eq(@rec["Address"])
    end


    it "maps 'Address2' to 'repository_with_agent.agent_representation.agent_contacts[0].address_2" do
      @obj.agent_representation['agent_contacts'][0]['address_2'].should eq(@rec["Address2"])
    end


    it "maps 'City' to 'repository_with_agent.agent_representation.agent_contacts[0].city" do
      @obj.agent_representation['agent_contacts'][0]['city'].should eq(@rec["City"])
    end


    it "maps 'State' to 'repository_with_agent.agent_representation.agent_contacts[0].region" do
      @obj.agent_representation['agent_contacts'][0]['region'].should eq(@rec["State"])
    end


    it "maps 'ZIPCode' and 'ZIPPlusFour' to 'repository_with_agent.agent_representation.agent_contacts[0].post_code" do
      @obj.agent_representation['agent_contacts'][0]['post_code'].should eq("#{@rec['ZIPCode']}-#{@rec['ZIPPlusFour']}")
    end


    it "maps 'Phone' and 'PhoneExtension' to 'repository_with_agent.agent_representation.agent_contacts[0].telephone" do
      @obj.agent_representation['agent_contacts'][0]['telephone'].should eq("#{@rec['Phone']} ext.#{@rec['PhoneExtension']}")
    end


    it "maps 'Fax' to 'repository_with_agent.agent_representation.agent_contacts[0].fax" do
      @obj.agent_representation['agent_contacts'][0]['fax'].should eq(@rec["Fax"])
    end


    it "maps 'Email' to 'repository_with_agent.agent_representation.agent_contacts[0].email" do
      @obj.agent_representation['agent_contacts'][0]['email'].should eq(@rec["Email"])
    end


    it "maps 'URL' to 'repository_with_agent.repository.url" do
      @obj.repository['url'].should eq(@rec["URL"])
    end


    it "maps 'EmailSignature' to 'repository_with_agent.agent_representation.agent_contacts[0].email_signature" do
      @obj.agent_representation['agent_contacts'][0]['email_signature'].should eq(@rec["EmailSignature"])
    end


    it "maps 'CountryID' to 'repository_with_agent.agent_representation.agent_contacts[0].country" do
      @obj.agent_representation['agent_contacts'][0]['country'].should eq(@rec["CountryID"])
    end
  end
end
