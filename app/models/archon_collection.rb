require_relative 'archon_mixins'

Archon.record_type(:collection) do
  plural 'collections'
  corresponding_record_type :resource
  include GenericArchivalObject

  def self.transform(rec)
    obj = super

    obj.level = 'collection'
    obj.title = rec['Title']

    c = Archon.record_type(:classification).find(rec['ClassificationID'])
    c_uri = ASpaceImport.JSONModel(c.aspace_type).uri_for(c.import_id)
    obj.classification = {:ref => c_uri}

    ids = c.resource_identifiers
    i = 0
    ids.each do |id|
      obj.send("id_#{i}=", id)
      i += 1
    end

    if rec['CollectionIdentifier'] && i < 4
      obj.send("id_#{i}=", rec['CollectionIdentifier'])
    end

    extent = model(:extent, 
                   {
                     :number => rec['Extent'],
                     :extent_type => get_extent_type(rec['ExtentUnitID']),
                     :portion => unspecified('whole')

                   })

    obj.extents = [extent]

    obj.dates << model(:date,
                       {
                         :expression => get_date_expression(rec),
                         :begin => rec['NormalDateBegin'],
                         :end => rec['NormalDateEnd'],
                         :date_type => 'inclusive',
                         :label => unspecified('other')
                       })
      
    if rec['PredominantDates']
      obj.dates << model(:date,
                         {
                           :expression => rec['PredominantDates'],
                           :date_type => 'bulk',
                           :label => unspecified('other')
                         })
    end

    obj.finding_aid_author = rec['FindingAidAuthor']

    #Notes
    if rec['Scope']
      obj.notes << model(:note_singlepart,
                         {
                           :content => [rec['Scope']],
                           :label => 'Scope and Contents',
                           :type => unspecified('abstract')
                         })
    end

    if rec['Abstract']
      obj.notes << model(:note_singlepart,
                         {
                           :content => [rec['Abstract']],
                           :label => 'Abstract',
                           :type => unspecified('abstract')
                         })
    end

    if rec['Arrangement']
      obj.notes << model(:note_singlepart,
                         {
                           :content => [rec['Arrangement']],
                           :label => 'Arrangement',
                           :type => unspecified('abstract')
                         })
    end

    # if rec['MaterialTypeID']
    #   type = Archon.record_type(:materialtype).find(rec['MaterialTypeID'])
    #   obj.resource_type = type['MaterialType']
    # end

    if rec['AcquisitionDate']
      obj.dates << model(:date,
                         {
                           :expression => rec['AcquisitionDate'],
                           :date_type => 'single',
                           :label => unspecified('other')
                         })
    end


    if rec['DescriptiveRulesID']
      obj.finding_aid_description_rules = desc_rule_code(rec['DescriptiveRulesID'])
    end

    {
      'RevisionHistory' => 'finding_aid_revision_description',
      'PublicationDate' => 'finding_aid_date',
      'PublicationNote' => 'finding_aid_note',
      'FindingLanguageID' => 'finding_aid_language',
    }.each do |k, v|
      obj[v] = rec[k]
    end

    if rec['Languages'][0]
      obj.language = rec['Languages'][0]
    end

    yield obj
  end


  def self.get_date_expression(rec)
    if rec['InclusiveDates']
      rec['InclusiveDates']
    else
      [rec['NormalDateBegin'], rec['NormalDateEnd']].join('-')
    end
  end


  def self.desc_rule_code(id)
    case id 
    when '1'; 'dacs'
    when '2'; 'aacr'
    when '3'; 'rad'
    when '4'; 'isadg'
    end
  end

end
