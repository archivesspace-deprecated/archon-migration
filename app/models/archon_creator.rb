Archon.record_type(:creator) do
  plural 'creators'

  def initialize(data)
    if data['CreatorTypeID'] && !data['CreatorTypeID'].is_a?(String)
      data['CreatorTypeID'] = data['CreatorTypeID'].to_s
    end

    super(data)
  end


  def self.transform(rec)

    unless rec.has_key?('ID')
      $log.warn("Ignoring Archon Creator record: #{self.inspect}")
      return
    end

    case rec['CreatorTypeID']
    when '19', '21', '23'
      obj =  model(:agent_person).new

      vals = {
        :primary_name => strip_html(rec['Name']),
        :fuller_form => rec['NameFullerForm'],
      }

      obj.names << model(:name_person, 
                         name_template(rec, vals))

      if rec['NameVariants']
        vals = {
          :primary_name => strip_html(rec['NameVariants']),
        }
        obj.names << model(:name_person,
                           name_template(rec, vals))
      end

    when '20'
      obj = model(:agent_family).new
      obj.names << model(:name_family, 
                         name_template(rec, {
                                         :family_name => rec['Name'],
                                       }))


    when '22'
      obj = model(:agent_corporate_entity).new
      obj.names << model(:name_corporate_entity, 
                         name_template(rec, {
                                         :primary_name => strip_html(rec['Name']),
                                       }))
    else
      $log.warn("Couldn't create an agent record from: #{rec.inspect}")
    end

    if rec['Dates']
      obj.dates_of_existence << model(:date,
                                      {
                                        :expression => rec['Dates'],
                                        :label => unspecified('existence'),
                                        :date_type => unspecified('single')
                                      })
    end

    obj.uri = obj.class.uri_for(rec.import_id)

    note = model(:note_bioghist).new
    if rec['BiogHist']
      note.subnotes << model(:note_text, 
                             {
                               :content => rec['BiogHist']
                             })
    end

    if rec['BiogHistAuthor']
      note.subnotes << model(:note_citation,
                             {
                               :content => ["Author: #{rec['BiogHistAuthor']}"]
                             })
    end

    if rec['Sources']
      sntype = obj.jsonmodel_type =~ /corporate/ ? :note_abstract : :note_citation
      note.subnotes << model(sntype,
                             {
                               :content => [rec['Sources']]
                             })
    end

    if rec['CreatorRelationships']
      rec['CreatorRelationships'].each do |archon_relationship|
        aspace_relationship = create_relationship(obj.jsonmodel_type, archon_relationship)
        obj.related_agents << aspace_relationship unless aspace_relationship.nil?
      end
    end

    unless note.subnotes.empty?
      obj.notes << note
    end

    yield obj
  end

 
  def self.name_template(rec, extra_vals = nil)
    extra_vals ||= {}

    unless extra_vals.has_key?(:source)
      extra_vals.merge!({:source => get_source(rec['CreatorSourceID'])})
    end

    super(rec, extra_vals)
  end


  def self.get_source(id)
    rec = Archon.record_type(:creatorsource).find(id)
    rec['SourceAbbreviation']
  end


  def self.create_relationship(relator_object_type, rel)
    archon_id = rel['RelatedCreatorID']
    relationship_code = rel['CreatorRelationshipTypeID']
    
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
