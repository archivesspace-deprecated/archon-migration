
Archon.record_type(:repository) do
  plural 'repositories'
  corresponding_record_type :repository_with_agent
  
  def self.transform(rec)
    obj = super

    repo = ASpaceImport.JSONModel(:repository).from_hash({
                                                           :name => rec["Name"],
                                                           :repo_code => rec["Name"],
                                                           :org_code => rec["Code"],
                                                           :url => rec["URL"],
                                                         })

    agent = ASpaceImport.JSONModel(:agent_corporate_entity).new
    agent.agent_contacts = [ contact_record(rec) ]
                                                                       
    obj.repository = repo
    obj.agent_representation = agent
    obj
  end


	def self.contact_record(rec)
    post_code = [rec["ZIPCode"], rec["ZIPPlusFour"]].compact.join('-')
    telephone = [rec["Phone"], rec["PhoneExtension"]].compact.join(' ext.')

    ASpaceImport.JSONModel(:agent_contact).from_hash({
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


Archon.record_type(:group) do
  plural 'usergroups'
  include Archon::EnumRecord

end


Archon.record_type(:user) do
  plural 'users'
  
end


Archon.record_type(:subjectsource) do
  plural 'subjectsources'
  include  Archon::EnumRecord
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

      obj = ASpaceImport.JSONModel(:subject).new
      obj.class.uri_for(rec["ID"])
      obj.terms = terms
      obj.external_ids = [{:external_id => rec["ID"], :source => "Archon"}]
      obj.vocabulary = '/vocabularies/1'
      obj.source = source["EADSource"]
    end

    obj
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

# ?p=core/creators&batch_start=1

# /?p=core/classifications&batch_start=1


# ?p=core/collections&batch_start=1
# ?p=core/accessions&batch_start=1
# ?p=core/content&cid=integer&batch_start=1




# ?p=core/digitalcontent&batch_start=1
# ?p=core/digitalfiles&batch_start=1
