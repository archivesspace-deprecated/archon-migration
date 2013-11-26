Archon.record_type(:subject) do
  plural 'subjects'
  no_html 'Subject'


  def self.transform(rec)
    if %w(3 8 10).include?(rec["SubjectTypeID"]) && rec['Parent'].nil?
      obj = transform_to_agent(rec)
    else
      terms = build_terms(rec)
      obj = model(:subject).new
      obj.terms = terms
      obj.external_ids = [{:external_id => rec["ID"], :source => "Archon"}]
      obj.vocabulary = '/vocabularies/1'
      obj.source = get_source(rec["SubjectSourceID"])
    end

    obj.uri = obj.class.uri_for(rec.import_id)

    if obj.respond_to?(:external_ids) && rec['ID']
      obj.external_ids << {:source => "Archon", :external_id => rec["ID"]}
    end

    yield obj
  end


  def self.get_source(id)
    rec = Archon.record_type(:subjectsource).find(id)
    rec ? rec['EADSource'] : unspecified('ingest')
  end


  def self.build_terms(rec, terms = [])
    if rec["Parent"] && rec['ParentID'] != '0'
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
    else; 'topical'
    end
  end


  def self.transform_to_agent(rec)
    case rec['SubjectTypeID']
    when '3'
      obj = model(:agent_corporate_entity).new
      obj.names << model(:name_corporate_entity,
                         name_template(rec).merge({
                                                    :primary_name => rec['Subject'],
                                                  }))
                         
    when '8'
      obj = model(:agent_person).new
      obj.names << model(:name_person,
                         name_template(rec).merge({
                                                    :primary_name => rec['Subject'],
                                                  }))
    when '10'
      obj = model(:agent_family).new
      obj.names << model(:name_family,
                         name_template(rec).merge({
                                                   :family_name => rec['Subject'],
                                                 }))
    end
    
    obj
  end


  def self.name_template(rec)
    hsh = super
    hsh.merge({:source => get_source(rec['SubjectSourceID'])})
  end
    
end
