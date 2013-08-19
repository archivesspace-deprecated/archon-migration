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

# /?p=core/classifications&batch_start=1
# ?p=core/collections&batch_start=1
# ?p=core/accessions&batch_start=1
Archon.record_type(:accession) do
  plural 'accessions'
end


# ?p=core/content&cid=integer&batch_start=1
# ?p=core/digitalcontent&batch_start=1
# ?p=core/digitalfiles&batch_start=1
