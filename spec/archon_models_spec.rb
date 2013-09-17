# -*- coding: utf-8 -*-
require_relative 'spec_helper'

describe "Archon record mappings" do

  before(:all) do 
    @archon = get_archon_client
    pending "Needs an Archon connection" unless @archon

    JSONModel.set_repository(1)
    Thread.current[:archivesspace_client] = MockArchivesSpaceClient.new 
  end


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


  def change(rec_orig, overwrites)
    data = rec_orig.instance_variable_get(:@data)
    data.merge!(overwrites)

    rec_orig.class.new(data)
  end

  shared_examples "archival object location mappings" do
    
    it "creates an instance for each item in 'Locations'" do
      instances = []
      record.tap_locations do |location, instance|
        instances << instance
        linked = instances.last['container']['container_locations'][0]
        linked['ref'].should eq(location.uri)
        linked['status'].should eq('current')

        instance['container']['container_extent'].should eq(record['Locations'][(instances.length - 1)]['Extent'])
      end

      instances.count.should eq(record['Locations'].count)
    end

    it "maps 'Content' to instances[].container.indicator_1" do
      instances = []
      record.tap_locations do |location, instance|
        instances << instance
      end

      cont = instances.map{|inst| inst['container']['indicator_1']}.sort

      cont.should eq(record['Locations'].map{|loc| loc['Content']}.sort)
    end


    it "uses 'Section' for indicator_1 value if 'RangeValue' is missing" do
      loc = record['Locations'][0].clone
      loc['RangeValue'] = nil

      obj = record.class.transform_location(loc)

      obj.coordinate_1_indicator.should eq(loc['Section'])
      obj.coordinate_1_label.should eq('Section')
      obj.coordinate_2_indicator.should eq(loc['Shelf'])
    end


    it "uses 'Shelf' for indicator_1 if 'RangeValue' and 'Section' are absent" do
      loc = record['Locations'][0].clone
      loc['RangeValue'] = nil
      loc['Section'] = nil

      obj = record.class.transform_location(loc)
      obj.coordinate_1_indicator.should eq(loc['Shelf'])
      obj.coordinate_2_indicator.should be_nil
    end


    it "uses 'not recorded' if no locations values are present" do
      loc = record['Locations'][0].clone
      %w(RangeValue Section Shelf).map {|spot| loc[spot] = nil}

      obj = record.class.transform_location(loc)
      obj.coordinate_1_indicator.should eq('not recorded')
    end
  end


  shared_examples "models that strip HTML from a given field" do

    it "strips HTML from certain fields" do
      field.should_not match(/<\/?[^<>\/]+>/)
    end
  end


  shared_examples "a content record with title and date" do
    it "maps 'Date' to *.dates[0].expression" do
      object.dates[0]['expression'].should eq(record['Date'])
    end

    it "maps 'Title' to *.title" do
      object.title.should eq(record['Title'])
    end
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


    it "uses 'Login' as a fallback for user.name" do
      data = @rec.instance_variable_get(:@data).clone
      data['DisplayName'] = nil

      rec = Archon.record_type(:user).new(data)
      obj = rec.class.to_obj(rec)

      obj.name.should_not be_nil
      obj.name.should eq(rec['Login'])
    end
  end


  describe "Repository" do
    before :all do
      @rec, results = create_test_set(:repository, %w(ID Name Code Address Address2 City State ZIPCode ZIPPlusFour Phone PhoneExtension Fax Email EmailSignature URL))
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

  end


  describe "Creator record" do 
    def t(rec)
      rec.class.transform(rec){|obj| obj}
    end

    def with(hash = {})
      create_test_set(
                      :creator,
                      text_fields,
                      template.merge(hash)
                      ) do |rec, set|
        yield rec, set.first
      end
    end


    let (:text_fields) { %w(ID Name NameFullerForm NameVariants Identifier BiogHist BiogHistAuthor Sources Dates) }
    let (:template) { {
        'CreatorSourceID' => '1',
        'CreatorTypeID' => '19',
        'CreatorRelationships' => [],
        'RepositoryID' => '1'
      } }
    let (:type_id) {'CreatorTypeID'}


    it "maps 'Name' to primary_name or family_name" do
      %w(19 22).each do |code|
        with({type_id => code}) do |rec, obj|
          obj.names[0]['primary_name'].should eq(rec['Name'])
        end
      end
      
      with({type_id => '20'}) do |rec, obj|
        obj.names[0]['family_name'].should eq(rec['Name'])
      end
    end


    it_behaves_like "models that strip HTML from a given field" do
      let(:field) {
        data = create_test_hash(text_fields, template.
                                merge({
                                        'Name' => '<b><h1>name</h1></b>'}))
        rec = Archon.record_type(:creator).new(data)
        obj = t(rec)
        name_string = obj.names[0]['primary_name']

        name_string
      }
    end


    it "maps 'NameFullerForm' to agent_person.names[0].fuller_form" do
      with({type_id => '19'}) do |rec, obj|
        obj.names[0]['fuller_form'].should eq(rec['NameFullerForm'])
      end
    end


    it "maps 'NameVariants' to agent_person.names[1].primary_name" do
      with({type_id => '19'}) do |rec, obj|
        obj.names[1]['primary_name'].should eq(rec['NameVariants'])
      end
    end


    it "uses the 'CreatorSource' lookup list to set agent_person.names[].source" do
      with({'CreatorSourceID' => '3'}) do |rec, obj|
        (0..1).each do |i|
          obj.names[i]['source'].should eq('CreSrcAbbr')
        end
      end
    end


    it "makes an agent_person for type ID 19, 21 and 23" do
      %w(19 21 23).each do |code|
        with({type_id => code}) do |rec, obj|
          obj.jsonmodel_type.should eq('agent_person')
        end
      end
    end


    it "makes an agent_family for type ID 20" do
      with({type_id => '20'}) do |rec, obj|
        obj.jsonmodel_type.should eq('agent_family')
      end
    end

    
    it "makes an agent_corporate_entity for type ID 22" do
      with({type_id => '22'}) do |rec, obj|
        obj.jsonmodel_type.should eq('agent_corporate_entity')
      end
    end


    it "maps 'Identifier' to 'agent.names[0].authority_id'" do
      with do |rec, obj|
        obj.names[0]['authority_id'].should eq(rec['Identifier'])
      end
    end


    it "maps 'Dates' to 'agent.dates_of_existece[0].expression'" do
      with do |rec, obj|
        obj.dates_of_existence[0]['expression'].should eq(rec['Dates'])
      end
    end


    it "maps 'BiogHist' to the first 'note_text' subnote of the first 'note_bioghist'" do
      with do |rec, obj|
        p obj
        notes = get_subnotes_by_type(obj.notes[0], 'note_text')
        notes[0]['content'].should eq(rec['BiogHist'])
      end
    end


    it "maps 'BiogHistAuthor' to the first 'note_citation' subnote of the first 'note_bioghist'" do
      with do |rec, obj|
        notes = get_subnotes_by_type(obj.notes[0], 'note_citation')
        notes[0]['content'][0].should eq("Author: #{rec['BiogHistAuthor']}")
      end
    end


    it "maps 'Sources' to either the second 'note_citation' or the first 'note_abstract' subnote" do
      with({type_id => '19'}) do |rec, obj|
        notes = get_subnotes_by_type(obj.notes[0], 'note_citation')
        notes[1]['content'][0].should eq(rec['Sources'])
      end

      #corporate_entity
      with({type_id => '22'}) do |rec, obj|
        notes = get_subnotes_by_type(obj.notes[0], 'note_abstract')
        notes[0]['content'][0].should eq(rec['Sources'])
      end
    end


    it "migrates Creator relationships" do
      with({
             type_id => '19', 
             'CreatorRelationships' => [
                                        {
                                          'RelatedCreatorID' => '4',
                                          'CreatorRelationshipTypeID' => '2'
                                        }
                                       ]
           }) do |rec, obj|
        related_agents = obj.related_agents
        related_agents[0]['relator'].should eq('is_parent_of')
        related_agents[0]['ref'].should eq('/agents/people/4')
      end
    end
    
  end


  describe "Subject record" do 
    def t(rec)
      rec.class.transform(rec){|obj| obj}
    end


    def with(hash = {})
      create_test_set(
                      :subject,
                      text_fields,
                      template.merge(hash)
                      ) do |rec, set|
        yield rec, set[0]
      end
    end

    let (:text_fields) { %w(Subject Identifier Description) }
    let (:template) { {
        'ID' => '1',
        'SubjectTypeID' => '1',
        'SubjectSourceID' => '2',
        'Parent' => nil,
        'ParentID' => '0'
      } }
    let (:type_id) {'SubjectTypeID'}

    it "creates an agent_person for subjects with type 8 unless the subject has a parent" do
      with(type_id => '8') do |rec, obj|
        obj.jsonmodel_type.should eq('agent_person')
      end
      
      parent_data = create_test_hash(text_fields, template)

      with({type_id => '8', 'Parent' => parent_data}) do |rec, obj|
        obj.jsonmodel_type.should eq('subject')
      end
    end

    it_behaves_like "models that strip HTML from a given field" do
      let(:field) {
        data = create_test_hash(text_fields, template.
                                merge({
                                        'Subject' => '<b><h1>test</h1></b>'}))
        rec = Archon.record_type(:subject).new(data)
        obj = t(rec)
        term_string = obj.terms.map{|term| term[:term]}.join('')
        term_string
      }
    end
  end


  describe "Classification record" do 

    def with(hash = {})
      create_test_set(
                      :classification,
                      text_fields,
                      template.merge(hash)
                      ) do |rec, set|
        yield rec, set
      end
    end


    let (:text_fields) { %w(ClassificationIdentifier Title Description) }
    let (:template) { {
        'ID' => '2',
        'ParentID' => '0',
        'CreatorID' => '0',
      } }


    it "creates a 'classification' if 'ParentID' is '0'; otherwise 'classification_term'" do
      with('ParentID' => '0') do |rec, set|
        set.first.jsonmodel_type.should eq('classification')
      end
      
      with('ParentID' => '1') do |rec, set|
        set.first.jsonmodel_type.should eq('classification_term')
      end
    end


    it "doesn't create a parent for a top-level term" do
      with('ParentID' => '1') do |rec, set|
        set.first.parent.should be_nil
      end

      with('ParentID' => '3') do |rec, set|
        set.first.parent.should_not be_nil
      end
    end
    

    it "maps 'ClassificationIdentifier' to classification.identifier" do
      %w(0 1).each do |i|
        with('ParentID' => i) do |rec, set|
          set.first.identifier.should eq(rec['ClassificationIdentifier'])
        end
      end
    end

    it "maps 'Title' to 'classification(_term)?.title'" do
      %w(0 1).each do |i|
        with('ParentID' => i) do |rec, set|
          set.first.title.should eq(rec['Title'])
        end
      end
    end


    it "maps 'Description' to *.description" do
      %w(0 1).each do |i|
        with('ParentID' => i) do |rec, set|
          set.first.description.should eq(rec['Description'])
        end
      end
    end


    it "can furnish a multi-part resource id" do
      rec = Archon.record_type(:classification).find('4')
      rec.resource_identifiers.should eq(['01', '01.A', '01.B'])
    end
  end


  describe "Archon Collection" do
    def t(rec)
      rec.class.transform(rec) { |obj| obj }
    end

    before(:all) do
      @rec = Archon.record_type(:collection).find('1')
      @obj = t(@rec)
    end


    it "always creates a resource with level = 'collection'" do
      @obj.level.should eq('collection')
    end


    it "assigns an import URI to the resource" do
      @obj.uri.should match(/resources\/import_.*-[0-9]+/)
    end


    it "maps 'Extent' to resource.extents[0].number" do
      @obj.extents[0]['number'].should eq(@rec['Extent'])
    end


    it "maps 'Title' to title" do
      @obj.title.should eq(@rec['Title'])
    end


    it "maps 'CollectionIdentifier' to the last id_*" do
      @obj.id_1.should eq(@rec['CollectionIdentifier'])
    end


    it "maps 'InclusiveDates' to dates[0] with type 'inclusive'" do
      @obj.dates[0]['date_type'].should eq('inclusive')
      @obj.dates[0]['expression'].should eq(@rec['InclusiveDates'])
    end


    it "maps 'PredominantDates' to dates[1] with type 'bulk'" do
      @obj.dates[1]['date_type'].should eq('bulk')
      @obj.dates[1]['expression'].should eq(@rec['PredominantDates'])
    end


    it "maps 'NormalDateBegin' and 'NormalDateEnd' to dates[0] begin and end" do
      @obj.dates[0]['begin'].should eq(@rec['NormalDateBegin'])
      @obj.dates[0]['end'].should eq(@rec['NormalDateEnd'])
    end


    it "maps 'FindingAidAuthor' to resource.finding_aid_author" do
      @obj.finding_aid_author.should eq(@rec['FindingAidAuthor'])
    end


    it "maps 'OtherURL' to resource.external_documents[].location" do
      @obj.external_documents[0].title.should eq('Other URL')
      @obj.external_documents[0].location.should eq(@rec['OtherURL'])
    end


    it "maps 'Scope' to a single part note" do
      @obj.notes[0]['jsonmodel_type'].should eq('note_singlepart')
      @obj.notes[0]['label'].should eq("Scope and Contents")
      @obj.notes[0]['content'][0].should eq(@rec['Scope'])
    end


    it "maps 'Abstract' to a single part note" do
      @obj.notes[1]['jsonmodel_type'].should eq('note_singlepart')
      @obj.notes[1]['label'].should eq("Abstract")
      @obj.notes[1]['content'][0].should eq(@rec['Abstract'])
    end


    it "maps 'Arrangement' to a single part note" do
      @obj.notes[2]['jsonmodel_type'].should eq('note_singlepart')
      @obj.notes[2]['label'].should eq("Arrangement")
      @obj.notes[2]['content'][0].should eq(@rec['Arrangement'])
    end


    it "maps 'MaterialTypeID' to resource_type" do
      type = Archon.record_type(:materialtype).find(@rec['MaterialTypeID'])['MaterialType']
      @obj.resource_type.should eq(type)
    end


    it "maps 'AltExtentStatement' to resource.extents[1].number" do
      e = @obj.extents[1]
      e['number'].should eq(@rec['AltExtentStatement'])
      e['portion'].should eq('whole')
      e['extent_type'].should eq('other_unmapped')
    end


    [
      {:archon_type => 'AccessRestrictions', 
       :note_type => 'accessrestrict', 
       :label => 'Conditions Governing Access'},

      {:archon_type => 'UseRestrictions', 
       :note_type => 'userestrict', 
       :label => 'Conditions Governing Use'},

      {:archon_type => 'PhysicalAccess', 
       :note_type => 'phystech', 
       :label => 'Physical Access Requirements'},

      {:archon_type => 'TechnicalAccess', 
       :note_type => 'phystech', 
       :label => 'Technical Access Requirements'},

      {:archon_type => 'AcquisitionSource', 
       :note_type => 'acqinfo', 
       :label => 'Source of Acquisition'},

      {:archon_type => 'AcquisitionMethod', 
       :note_type => 'acqinfo', 
       :label => 'Method of Acquisition'},

      {:archon_type => 'AppraisalInfo', 
       :note_type => 'appraisal', 
       :label => 'Appraisal Information'},

      {:archon_type => 'AccrualInfo', 
       :note_type => 'accruals', 
       :label => 'Accruals and Additions'},

      {:archon_type => 'CustodialHistory', 
       :note_type => 'custodhist', 
       :label => 'Custodial History'},

     {:archon_type => 'RelatedPublications', 
       :note_type => 'relatedmaterial', 
       :label => 'Related Publications'},

     {:archon_type => 'SeparatedMaterials', 
       :note_type => 'separatedmaterial', 
       :label => 'Separated Materials'},

     {:archon_type => 'PreferredCitation', 
       :note_type => 'prefercite', 
       :label => 'Preferred Citation'},

     {:archon_type => %w(OrigCopiesNote OrigCopiesURL), 
       :note_type => 'originalsloc', 
       :label => 'Existence and Location of Originals'},

     {:archon_type => %w(OtherNote OtherURL), 
       :note_type => 'odd', 
       :label => "Other Descriptive Information"},

     {:archon_type => %w(BiogHist BiogHistAuthor),
       :note_type => 'bioghist',
       :label => "Biographical or Historical Information",
       :joint => "Note written by "
     },

     {:archon_type => %w(RelatedMaterials RelatedMaterialsURL),
       :note_type => 'relatedmaterial',
       :label => "Related Materials"
     }

    ].each do |test_data|
      src_label = [test_data[:archon_type]].flatten.join(", ")
      joint = test_data.has_key?(:joint) ? test_data[:joint] : " "
      it "maps #{src_label} to #{test_data[:note_type]}" do
        src_value = [test_data[:archon_type]].flatten.map{|k| @rec[k] }.join(joint)
        notes = get_notes_by_type(@obj, test_data[:note_type])
        n = notes.find{|n| n['label'] == test_data[:label]}
        n.should_not be_nil
        n.subnotes[0]['content'].should eq(src_value)
      end
    end


    it "maps 'AcquisitionDate' to dates[].expression" do
      @obj.dates[2]['expression'].should eq("Date acquired: 2012-01-01")
    end


    it "formats 'AcquisitionDate' to yyyy-mm-dd and chooses appropriate granularity" do

      obj1 = t(change(@rec, 'AcquisitionDate' => '19991231'))
      obj1.dates[2]['expression'][-10..-1].should eq('1999-12-31')
      
      obj2 = t(change(@rec, 'AcquisitionDate' => '18880001'))
      obj2.dates[2]['expression'][-4..-1].should eq('1888')
    end


    it "maps 'DescriptiveRulesID' to resource.finding_aid_description_rules" do
      @obj.finding_aid_description_rules.should eq('aacr')
    end


    it "maps 'RevisionHistory' to 'resource:finding_aid_revision_description'" do
      @obj.finding_aid_revision_description.should eq(@rec['RevisionHistory'])
    end


    it "maps 'PublicationDate' to 'resource:finding_aid_date'" do
      @obj.finding_aid_date.should eq(@rec['PublicationDate'])
    end


    it "maps 'PublicationNote' to 'resource:finding_aid_note'" do
      @obj.finding_aid_note.should eq(@rec['PublicationNote'])
    end


    it "maps 'FindingLanguageID' to 'resource:finding_aid_language'" do
      @obj.finding_aid_language.should eq('eng')
    end


    # it "maps the first element in 'Languages' to resource.language" do
    #   @obj.language.should eq(@rec['Languages'][0])
    # end


    it_behaves_like "archival object location mappings" do
      let(:object) { @obj }
      let(:record) { @rec }
    end


    it_behaves_like "models that strip HTML from a given field" do
      let(:field) {
        obj = t(change(@rec, 'Title' => "<b><span class=\"hi\">hi</span></b>"))
        obj.title
      }
    end
  end


  describe "Archon Accession" do
    before(:all) do
      @rec = Archon.record_type(:accession).find('1')
      @rec.class.transform(@rec) do |obj|
        if obj.jsonmodel_type == 'accession'
          @obj = obj
        elsif obj.jsonmodel_type == 'agent_person'
          @donor = obj
        end
      end
    end

    it "maps 'Enabled' to accession.publish" do
      @obj.publish.should be_true
      @rec.class.transform(change(@rec, {'Enabled' => '0'})) do |obj|
        if obj.jsonmodel_type == 'accession'
          obj.publish.should_not be_true
        end
      end
    end


    it "maps 'AccessionDate'" do
      @obj.accession_date.should eq(@rec['AccessionDate'])
    end
    

    it "maps 'InclusiveDates'" do
      @obj.dates[0].expression.should eq(@rec['InclusiveDates'])
    end


    it "maps 'ReceivedExtent'" do
      @obj.extents[0]['number'].should eq(@rec['ReceivedExtent'])
    end


    it "maps 'MaterialTypeID'" do
      type = Archon.record_type(:materialtype).find(@rec['MaterialTypeID'])['MaterialType']
      @obj.resource_type.should eq(type)
    end


    it "maps 'ProcessingPriorityID'" do
      @obj.collection_management['processing_priority'].should eq('ProcessPriorityMgr.ProcessingPriority-Archon')
    end


    it "maps 'ExpectedCompletionDate'" do
      @obj.collection_management['processing_plan'].should eq("Expected Completion Date: " + @rec['ExpectedCompletionDate'])
    end

 
    it "maps 'DonorContactInformation'" do
      @donor.agent_contacts[0].address_1.should eq(@rec['DonorContactInformation'])
    end


    it "maps 'DonorNotes'" do
      @donor.agent_contacts[0].note.should eq(@rec['DonorNotes'])
    end


    it "maps 'PhysicalDescription'" do
      @obj.condition_description.should eq @rec['PhysicalDescription']
    end


    it "maps 'ScopeContent'" do
      @obj.content_description.should eq(@rec['ScopeContent'])
    end


    it "maps 'Comments'" do
      @obj.general_note.should eq(@rec['Comments'])
    end


    it_behaves_like "archival object location mappings" do
      let(:object) { @obj }
      let(:record) { @rec }
    end    
  end


  describe "Archon Content" do
    def t(rec)
      rec.class.to_archival_object(rec)
    end

    before(:all) do
      @rec = Archon.record_type(:content).set(1).find(1)
      @obj = t(@rec)
    end 

    let(:klass) { Archon.record_type(:content) }

    it "yields an archival object if ContentType is 1 or 3" do
      {'1' => [true], '2' => [false], '3' => [true, false]}.each do |ct, boolean|
        @rec.class.transform(change(@rec, {'ContentType' => ct})) do |obj|
          (obj.respond_to?(:jsonmodel_type)).should eq(boolean.shift)
        end
      end
    end


    it "maps 'EADLevel' to aa.level"do
      @rec.class.transform(change(@rec, {'ContentType' => '1'})) do |obj|        
        obj.level.should eq(@rec['EADLevel'])
      end
    end


    it_behaves_like "models that strip HTML from a given field" do
      let(:field) {
        rec = change(@rec, {'Title' => "<b><span class=\"oh\">hello</span></b>"})
        t(rec).title
      }
    end


    it_behaves_like "a content record with title and date" do
      let (:object) { t(@rec) }
      let (:record) { @rec }
    end


    it "links intellectual objects to their parents" do 
      rec1, rec2 = [1,2].map {|i| Archon.record_type(:content).set(1).find(i) }
      parent = Archon.record_type(:content).to_archival_object(rec1)
      child = Archon.record_type(:content).to_archival_object(rec2)
      child.parent['ref'].should eq(parent.uri)
    end


    it "links intellectual objects to their resource root" do
      rec = Archon.record_type(:content).set(1).find(1)
      resource_id = Archon.record_type(:collection).find(1).import_id
      resource_uri = ASpaceImport.JSONModel(:resource).uri_for(resource_id)

      obj = klass.to_archival_object(rec)
      obj.resource['ref'].should eq(resource_uri)
    end


    it "links to the first ancestor that isn't physical only" do
      top = klass.find(2)
      mid = klass.find(3)
      bot = klass.find(4)

      mid['ContentType'].should eq('2')

      t(bot).parent['ref'].should eq(t(top).uri)
    end


    it "maps 'PrivateTitle' to a 'materialspec' note_singlepart" do
      n = get_notes_by_type(@obj, 'materialspec')[0]
      n.label.should eq('Private Title')
      n.publish.should be_false
      n.content[0].should eq(@rec['PrivateTitle'])
    end


    it "maps 'Description' to 'scopecontent' note_multipart" do
      n = get_notes_by_type(@obj, 'scopecontent')[0]
      n.subnotes[0]['content'].should eq(@rec['Description'])
    end


    it "maps 'SortOrder' to 'position'" do
      @obj.position.should eq(@rec['SortOrder'].to_i - 1)
    end


    it "maps 'UniqueID' to 'component_id'" do
      @obj.component_id.should eq(@rec['UniqueID'])
    end


    it "maps 'Notes' to 'notes'" do

      @rec['Notes'].values.each do |note_data|
        note_type = case note_data['NoteType']
                    when 'origination', 'langmaterial', 'note', 'unitid'
                      'odd'
                    when 'extent'
                      'physdesc'
                    else
                      note_data['NoteType']
                    end
        nn = get_notes_by_type(@obj, note_type)
        note = nn.find{|n| n.label == note_data['Label']}
        note.should_not be_nil
        get_note_content(note).should eq(note_data['Content'])
      end
    end
  end


  describe "Archon Digital Content" do
    def t(rec)
      rec.class.to_digital_object(rec)
    end
    
    before(:all) do
      @rec = Archon.record_type(:digitalcontent).find(1)
      @obj = t(@rec)
    end


    it_behaves_like "a content record with title and date" do
      let (:object) { @obj }
      let (:record) { @rec }
    end


    it_behaves_like "models that strip HTML from a given field" do
      let(:field) {
        rec = change(@rec, 'Title' => "<br /><span>hello</span><br />")
        t(rec).title
      }
    end


    it "maps 'ID' to *.external_ids[]" do
      @obj.external_ids[0]['external_id'].should eq(@rec['ID'])
    end


    it "maps 'Identifier' to *.digital_object_id" do
      @obj.digital_object_id.should eq(@rec['Identifier'])
    end


    it "maps 'Title' to *.title" do
      @obj.title.should eq(@rec['Title'])
    end

    {
      'Scope' => 'summary',
      'PhysicalDescription' => 'physical_description',
      'Publisher' => 'other_unmapped',
      'Contributor' => 'note',
      'RightsStatement' => 'userestrict',
    }.each do |field, note_type|
      it "maps #{field} to *.note_digital_object[type=#{note_type}]" do
        prefix = %w(Publisher Contributor).include?(field) ? "#{field}: " : ""
        notes = get_notes_by_type(@obj, note_type)
        notes[0]['content'][0].should eq(prefix + @rec[field])
      end
    end


    it "maps 'ContentURL' to *.file_versions[0]['file_uri']" do
      @obj.file_versions[0]['file_uri'].should eq(@rec['ContentURL'])
    end
  end


  describe "Archon Digital File" do
    before(:all) do
      @rec = Archon.record_type(:digitalfile).find(1)
      @obj = @rec.class.to_digital_object_component(@rec)
    end


    it "maps 'Title' to digital_object_component.label" do
      @obj.label.should eq(@rec['Title'])
    end


    it "lets a user set a base_url for file_version.file_uri" do
      base = "http://example.com"
      @rec.class.base_url = base
      new_obj = @rec.class.to_digital_object_component(@rec)
      new_obj.file_versions[0]['file_uri'].should match(Regexp.new(base))
    end

  end

end
