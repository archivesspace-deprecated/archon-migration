Archon.record_type(:creator) do
  self.plural 'creators'

  def self.transform(rec)

    case rec['CreatorTypeID']
    when '19', '21', '23'
      obj =  model(:agent_person).new
      obj.names << model(:name_person, 
                         name_template(rec).merge({
                                                    :primary_name => rec['Name'],
                                                    :fuller_form => rec['NameFullerForm'],
                                             }))
      unless rec['NameVariants'].empty?
        obj.names << model(:name_person,
                           name_template(rec).merge({
                                                      :primary_name => rec['NameVariants'],
                                                    }))
      end

    when '20'
      obj = model(:agent_family).new
      obj.names << model(:name_family, 
                         name_template(rec).merge({
                                                    :family_name => rec['Name'],
                                                  }))


    when '22'
      obj = model(:agent_corporate_entity).new
      obj.names << model(:name_corporate_entity, 
                         name_template(rec).merge({
                                                    :primary_name => rec['Name'],
                                                  }))
    end

    unless rec['Dates'].empty?
      obj.dates_of_existence << model(:date,
                                      {
                                        :expression => rec['Dates'],
                                        :label => unspecified('existence'),
                                        :date_type => unspecified('single')
                                      })
    end

    note = model(:note_bioghist).new
    unless rec['BiogHist'].empty?
      note.subnotes << model(:note_text, 
                             {
                               :content => rec['BiogHist']
                             })
    end

    unless rec['BiogHistAuthor'].empty?
      note.subnotes << model(:note_citation,
                             {
                               :content => ["Author: #{rec['BiogHistAuthor']}"]
                             })
    end

    unless rec['Sources'].empty?
      sntype = obj.jsonmodel_type =~ /corporate/ ? :note_abstract : :note_citation
      note.subnotes << model(sntype,
                             {
                               :content => [rec['Sources']]
                             })
    end

    rec['CreatorRelationships'].each do |archon_relationship|
      aspace_relationship = create_relationship(obj.jsonmodel_type, archon_relationship)
      obj.related_agents << aspace_relationship unless aspace_relationship.nil?
    end

    unless note.subnotes.empty?
      obj.notes << note
    end

    yield obj
  end

 
  def self.name_template(rec)
    hsh = super
    hsh.merge({:source => get_source(rec['CreatorSourceID'])})
  end


  def self.get_source(id)
    rec = Archon.record_type(:creatorsource).find(id)
    rec['SourceAbbreviation']
  end


  def self.create_relationship(relator_object_type, rel)
    archon_id, relationship_code = *rel.flatten
    
    case relator_object_type
    when 'agent_person'
      case relationship_code
      when '2'
        relation = Archon.record_type(:creator).find(archon_id)
        if %w(19 21 23).include? relation['CreatorTypeID']
          model(:agent_relationship_parentchild,
                {
                  :ref => model(:agent_person).uri_for(relation["ID"]),
                  :relator => 'is_parent_of'
                 })
        else
          raise "unable to related these records"
        end
      end
    end
  end
end
