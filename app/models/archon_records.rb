# Lookup Lists
Archon.record_type(:subjectsource) do
  plural 'subjectsources'
  include  Archon::EnumRecord
end


Archon.record_type(:creatorsource) do
  plural 'creatorsources'
  include Archon::EnumRecord
end


Archon.record_type(:repository) do
  plural 'repositories'
  corresponding_record_type :repository_with_agent
  
  def self.transform(rec)
    obj = super

    agent = model(:agent_corporate_entity).new
    agent.agent_contacts = [ contact_record(rec) ]
    agent.names << model(:name_corporate_entity, {
                           :primary_name => rec["Name"],
                           :source => 'local',
                           :sort_name_auto_generate => true
                         })


    repo = model(:repository, {
                   :name => rec["Name"],
                   :repo_code => rec["Name"],
                   :org_code => rec["Code"],
                   :url => rec["URL"],
                 })

    repo.agent_representation = {:ref => agent.uri}
    repo.uri = repo.class.uri_for(rec["ID"])

    yield agent
    yield repo                                                                       
  end


	def self.contact_record(rec)
    post_code = [rec["ZIPCode"], rec["ZIPPlusFour"]].compact.join('-')
    telephone = [rec["Phone"], rec["PhoneExtension"]].compact.join(' ext.')

    model(:agent_contact, {
      :name => rec["Name"],
      :address_1 => rec["Address"],
      :address_2 => rec["Address2"],
      :city => rec["City"],
      :region => rec["State"],
      :post_code => post_code,
      :telephone => telephone,
      :fax => rec['Fax'],
      :email => rec['Email'],
      :email_signature => rec["EmailSignature"],
      :country => rec["CountryID"]  
    })
	end
end


Archon.record_type(:user) do
  plural 'users'
  corresponding_record_type :user
  
  def self.transform(rec)
    return nil unless (rec['IsAdminUser'] == '1')
    obj = super
    obj.email = rec['Email']
    # ASpace comes with an 'admin' user out of the box
    obj.username = rec['Login'] == 'admin' ? '_admin' : rec['Login']
    obj.name = rec['DisplayName']
    obj.first_name = rec["FirstName"]
    obj.last_name = rec['LastName']

    yield obj
  end
end


Archon.record_type(:subject) do
  self.plural 'subjects'

  def self.transform(rec)
    # build an agent
    if %w(3 8 10).include?(rec["SubjectTypeID"])
      return
    # build a subject
    else
      terms = build_terms(rec)
      source = Archon.record_type(:subjectsource).find(rec["SubjectSourceID"])

      obj = model(:subject).new
      obj.class.uri_for(rec["ID"])
      obj.terms = terms
      obj.external_ids = [{:external_id => rec["ID"], :source => "Archon"}]
      obj.vocabulary = '/vocabularies/1'
      obj.source = source["EADSource"]
    end

    yield obj
  end


  def self.build_terms(rec, terms = [])
    if rec["Parent"]
      terms = build_terms(rec["Parent"], terms)
    end

    terms << {:term => rec["Subject"], :term_type => term_type(rec["SubjectTypeID"]), :vocabulary => '/vocabularies/1'}

    terms
  end


  def self.term_type(archon_subject_type_id)
    case archon_subject_type_id
    when '4'; 'function'
    when '5'; 'genre_form'
    when '6'; 'geographic'
    when '7'; 'occupation'
    when '2'; 'temporal'
    when '1'; 'topical'
    when '9'; 'uniform_title'
    end
  end
end


Archon.record_type(:creator) do
  self.plural 'creators'

  def self.transform(rec)
    name_source = get_source(rec['CreatorSourceID'])

    case rec['CreatorTypeID']
    when '19', '21', '23'
      obj =  model(:agent_person).new
      obj.names << model(:name_person, 
                         name_template.merge({
                                               :primary_name => rec['Name'],
                                               :fuller_form => rec['NameFullerForm'],
                                               :source => name_source
                                             }))
      unless rec['NameVariants'].empty?
        obj.names << model(:name_person,
                           name_template.merge({
                                                 :primary_name => rec['NameVariants'],
                                                 :source => name_source
                                               }))
      end

    when '20'
      obj = model(:agent_family).new
      obj.names << model(:name_family, 
                         name_template.merge({
                                               :family_name => rec['Name'],
                                               :source => name_source
                                             }))


    when '22'
      obj = model(:agent_corporate_entity).new
      obj.names << model(:name_corporate_entity, 
                         name_template.merge({
                                               :primary_name => rec['Name'],
                                               :source => name_source
                                             }))
    end

    yield obj
  end

 
  def self.name_template
    {
      :name_order => unspecified('direct'),
      :source => unspecified('local'),
      :sort_name_auto_generate => true
    }
  end


  def self.get_source(id)
    rec = Archon.record_type(:creatorsource).find(id)
    rec['SourceAbbreviation']
  end
end

# /?p=core/classifications&batch_start=1
# ?p=core/collections&batch_start=1
# ?p=core/accessions&batch_start=1
# ?p=core/content&cid=integer&batch_start=1
# ?p=core/digitalcontent&batch_start=1
# ?p=core/digitalfiles&batch_start=1
