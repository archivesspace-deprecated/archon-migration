require_relative 'spec_helper'

describe "Archon record mappings" do

  def create_test_hash(fields, template = {})
    data = Hash[fields.map{ |field| [field, rand(36**4).to_s(36)] }]
    if data["URL"]
      data["URL"] = "http://example.com"
    end

    data.merge(template)
  end


  def transform(klass, data)
    results = []
    klass.transform(klass.new(data)){|obj| results << obj}
    results
  end


  def create_test_set(type, fields, template = {})
    data = create_test_hash(fields, template)
    pp data
    rec = Archon.record_type(type).new(data)
    results = transform(rec.class, data)

    if block_given?
      yield rec, results
    else
      return rec, results
    end
  end


  def mapped?(rec_key, obj_key)
    @rec[rec_key].should_not be_nil
    @rec[rec_key].should eq(@obj.send(obj_key))
  end


  before(:all) do
    Thread.current[:archivesspace_client] = MockArchivesSpaceClient.new 
  end


  describe "Users" do
    before :all do

      @rec, results = create_test_set(
                                    :user, 
                                    %w(ID Login Email FirstName LastName DisplayName),
                                    {'IsAdminUser' => '1'}
                                    )
      @obj = results.shift
    end

    
    it "maps 'Login' to 'username'" do
      mapped?('Login', 'username')
    end


    it "maps 'Email' to 'email'" do
      mapped?('Email', 'email')
    end


    it "maps 'FirstName' to 'first_name'" do
      mapped?('FirstName', 'first_name')
    end


    it "maps 'LastName' to 'last_name'" do
      mapped?('LastName', 'last_name')
    end


    it "ignores archon users that aren't admins" do
      data = @rec.instance_variable_get(:@data).clone
      results = transform(Archon.record_type(:user), data)
      results.length.should eq(1)

      data['IsAdminUser'] = '0'
      results = transform(Archon.record_type(:user), data)
      results.length.should eq(0)
    end
  end


  describe "Repository" do
    before :all do
      @rec, results = create_test_set(:repository, %w(ID Name Code Address Address2 City State ZIPCode ZIPPlusFour Phone PhoneExtension Fax Email EmailSignature CountryID URL))
      @agent = results.shift
      @repo = results.shift
    end


    it "maps 'Name' to 'name'" do
      @repo['name'].should_not be_nil
      @repo['name'].should eq(@rec["Name"])
    end


    it "maps 'Code' to 'org_code'" do
      @repo['org_code'].should_not be_nil
      @repo['org_code'].should eq(@rec["Code"])
    end


    it "maps 'Address' to 'repository_with_agent.agent_representation.agent_contacts[0].address_1" do
      @agent['agent_contacts'][0]['address_1'].should eq(@rec["Address"])
    end


    it "maps 'Address2' to 'repository_with_agent.agent_representation.agent_contacts[0].address_2" do
      @agent['agent_contacts'][0]['address_2'].should eq(@rec["Address2"])
    end


    it "maps 'City' to 'repository_with_agent.agent_representation.agent_contacts[0].city" do
      @agent['agent_contacts'][0]['city'].should eq(@rec["City"])
    end


    it "maps 'State' to 'repository_with_agent.agent_representation.agent_contacts[0].region" do
      @agent['agent_contacts'][0]['region'].should eq(@rec["State"])
    end


    it "maps 'ZIPCode' and 'ZIPPlusFour' to 'repository_with_agent.agent_representation.agent_contacts[0].post_code" do
      @agent['agent_contacts'][0]['post_code'].should eq("#{@rec['ZIPCode']}-#{@rec['ZIPPlusFour']}")
    end


    it "maps 'Phone' and 'PhoneExtension' to 'repository_with_agent.agent_representation.agent_contacts[0].telephone" do
      @agent['agent_contacts'][0]['telephone'].should eq("#{@rec['Phone']} ext.#{@rec['PhoneExtension']}")
    end


    it "maps 'Fax' to 'repository_with_agent.agent_representation.agent_contacts[0].fax" do
      @agent['agent_contacts'][0]['fax'].should eq(@rec["Fax"])
    end


    it "maps 'Email' to 'repository_with_agent.agent_representation.agent_contacts[0].email" do
      @agent['agent_contacts'][0]['email'].should eq(@rec["Email"])
    end


    it "maps 'URL' to 'repository_with_agent.repository.url" do
      @repo['url'].should eq(@rec["URL"])
    end


    it "maps 'EmailSignature' to 'repository_with_agent.agent_representation.agent_contacts[0].email_signature" do
      @agent['agent_contacts'][0]['email_signature'].should eq(@rec["EmailSignature"])
    end


    it "maps 'CountryID' to 'repository_with_agent.agent_representation.agent_contacts[0].country" do
      @agent['agent_contacts'][0]['country'].should eq(@rec["CountryID"])
    end
  end


  describe "Creator record" do 
    before(:all) do 
      @archon = get_archon_client
      pending "Needs an Archon connection" unless @archon
    end

    def with(hash = {})
      create_test_set(
                      :creator,
                      text_fields,
                      template.merge(hash)
                      ) do |rec, set|
        yield rec, set
      end
    end


    let (:text_fields) { %w(ID Name NameFullerForm NameVariants Identifier Bioghist BioghistAuthor Sources Dates) }
    let (:template) { {
        'CreatorSourceID' => '1',
        'CreatorTypeID' => '19',
        'CreatorRelationships' => [],
        'RepositoryID' => '1'
      } }
    let (:type_id) {'CreatorTypeID'}


    it "maps 'Name' to primary_name or family_name" do
      %w(19 22).each do |code|
        with({type_id => code}) do |rec, set|
          set.first.names[0]['primary_name'].should eq(rec['Name'])
        end
      end
      
      with({type_id => '20'}) do |rec, set|
        set.first.names[0]['family_name'].should eq(rec['Name'])
      end
    end


    it "maps 'NameFullerForm' to agent_person.names[0].fuller_form" do
      with({type_id => '19'}) do |rec, set|
        set.first.names[0]['fuller_form'].should eq(rec['NameFullerForm'])
      end
    end


    it "maps 'NameVariants' to agent_person.names[1].primary_name" do
      with({type_id => '19'}) do |rec, set|
        set.first.names[1]['primary_name'].should eq(rec['NameVariants'])
      end
    end


    it "uses the 'CreatorSource' lookup list to set agent_person.names[].source" do
      with({'CreatorSourceID' => '3'}) do |rec, set|
        (0..1).each do |i|
          set.first.names[i]['source'].should eq('CreSrcAbbr')
        end
      end
    end


    it "makes an agent_person for type ID 19, 21 and 23" do
      %w(19 21 23).each do |code|
        with({type_id => code}) do |rec, set|
          set.first.jsonmodel_type.should eq('agent_person')
        end
      end
    end


    it "makes an agent_family for type ID 20" do
      with({type_id => '20'}) do |rec, set|
        set.first.jsonmodel_type.should eq('agent_family')
      end
    end

    
    it "makes an agent_corporate_entity for type ID 22" do
      with({type_id => '22'}) do |rec, set|
        set.first.jsonmodel_type.should eq('agent_corporate_entity')
      end
    end


    it "maps 'Identifier' to 'agent.names[0].authority_id'" do
      with do |rec, set|
        set.first.names[0]['authority_id'].should eq(rec['Identifier'])
      end
    end


    it "maps 'Dates' to 'agent.dates_of_existece[0].expression'" do
      with do |rec, set|
        set.first.dates_of_existence[0]['expression'].should eq(rec['Dates'])
      end
    end


    it "maps 'Bioghist' to the first 'note_text' subnote of the first 'note_bioghist'" do
      with do |rec, set|
        notes = get_subnotes_by_type(set.first.notes[0], 'note_text')
        notes[0]['content'].should eq(rec['Bioghist'])
      end
    end


    it "maps 'BioghistAuthor' to the first 'note_citation' subnote of the first 'note_bioghist'" do
      with do |rec, set|
        notes = get_subnotes_by_type(set.first.notes[0], 'note_citation')
        notes[0]['content'][0].should eq("Author: #{rec['BioghistAuthor']}")
      end
    end


    it "maps 'Sources' to either the second 'note_citation' or the first 'note_abstract' subnote" do
      with({type_id => '19'}) do |rec, set|
        notes = get_subnotes_by_type(set.first.notes[0], 'note_citation')
        notes[1]['content'][0].should eq(rec['Sources'])
      end

      #corporate_entity
      with({type_id => '22'}) do |rec, set|
        notes = get_subnotes_by_type(set.first.notes[0], 'note_abstract')
        notes[0]['content'][0].should eq(rec['Sources'])
      end
    end


    it "migrates Creator relationships" do
      with({
             type_id => '19', 
             'CreatorRelationships' => [
                                        {'4' => '2'}, 
                                        #{'2' => '5'} TODO after spec clarification
                                       ]
           }) do |rec, set|
        related_agents = set.first.related_agents
        related_agents[0]['relator'].should eq('is_parent_of')
        related_agents[0]['ref'].should eq('/agents/people/4')
      end
    end
    
  end
end
