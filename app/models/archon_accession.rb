require_relative 'archon_mixins'

Archon.record_type(:accession) do
  plural 'accessions'
  corresponding_record_type :accession
  include GenericArchivalObject

  def self.transform(rec)
    obj = super
    
    obj.publish = rec['Enabled'] == '1' ? true : false

    obj.accession_date = rec['AccessionDate']
    obj.title = rec['Title']
    obj.id_0 = rec['Identifier']
    
    if rec['InclusiveDates']
      obj.dates << model(:date,
                         {
                           :expression => rec['InclusiveDates'],
                           :date_type => 'inclusive',
                           :label => unspecified('other')
                         })
    end

    if rec['ReceivedExtent']
      obj.extents << model(:extent,
                           {
                             :number => rec['ReceivedExtent'],
                             :extent_type => get_extent_type(rec['ReceivedExtentUnitID']),
                             :portion => 'whole',
                             :container_summary => 'Received Extent'
                           })
    end

    obj.collection_management = build_coll_mgmt(rec)
    
    if rec['Donor']
      donor = model(:agent_person).new
      donor.names << model(:name_person,
                           name_template.merge({
                                                 :primary_name => rec['Donor'],
                                                 :source => unspecified('ingest')
                                               })
                           )

      donor.agent_contacts << model(:agent_contact,
                                    :name => rec['Donor']
                                    )

      if rec['DonorContactInformation']
        donor.agent_contacts[0].address_1 = rec['DonorContactInformation']
      end

      if rec['DonorNotes']
        donor.agent_contacts[0].note = rec['DonorNotes']
      end


      yield donor

      obj.linked_agents << {
        :ref => donor.uri,
        :role => 'source'
      }
    end

    if rec['PhysicalDescription']
      obj.condition_description = rec['PhysicalDescription']
    end

    if rec['ScopeContent']
      obj.content_description = rec['ScopeContent']
    end

    if rec['Comments']
      obj.general_note = rec['Comments']
    end

    # fix this
    while rec['Classifications'].length > 1
      c = rec['Classifications'].pop
      $log.warn("Cannot migration Accession Link to Classification #{c}")
    end

    if rec['Classifications'].length == 1
      c = Archon.record_type(:classification).find(rec['Classifications'][0])
      c_uri = ASpaceImport.JSONModel(c.aspace_type).uri_for(c.import_id)
      obj.classification = {:ref => c_uri}
    end

    yield obj
  end


  def self.build_coll_mgmt(rec)
    obj = model(:collection_management).new
    if rec['ProcessingPriorityID']
      obj.processing_priority = get_processing_priority(rec['ProcessingPriorityID'])
    end

    if rec['ExpectedCompletionDate']
      obj.processing_plan = "Expected Completion Date: #{rec['ExpectedCompletionDate']}"
    end

    obj
  end
end
