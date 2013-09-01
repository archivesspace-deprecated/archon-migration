require_relative 'archon_mixins'

Archon.record_type(:collection) do
  plural 'collections'
  corresponding_record_type :resource
  include GenericArchivalObject

  def self.transform(rec)
    obj = super

    raise obj if obj.id_0

    obj.key = rec['ID']
    obj.level = 'collection'
    obj.title = rec['Title']

    c = Archon.record_type(:classification).find(rec['ClassificationID'])
    if c.nil?
      $log.warn(%{Archon Collection record has '#{rec['ClassificationID']}' for its ClassificationID foreign key, but no such record exists. The Archon record id is '#{rec['ID']}'. Assigning a random ID to the ArchivesSpace resource.})

      ids = []
    else
      c_uri = ASpaceImport.JSONModel(c.aspace_type).uri_for(c.import_id)
      obj.classification = {:ref => c_uri}
      ids = c.resource_identifiers
    end

    max = rec['CollectionIdentifier'] ? 3 : 4
    while ids.length > max
      rejected = ids.pop
      $log.warn("Deleting a Classification id (#{rejected}) from the resource. Archon record: #{rec.inspect}")
    end

    i = 0
    ids.each do |id|
      obj.send("id_#{i}=", id.clone) #TODO: Classification returns clean set
      i += 1
    end

    if rec['CollectionIdentifier'] && i < 4
      obj.send("id_#{i}=", rec['CollectionIdentifier'])
    end

    if obj.id_0.nil?
      $log.warn("Couldn't find anything to assign to 'resource.id_0'. Generating a random value. See Archon record #{rec.inspect}")
#      obj.id_0 = "migration_#{SecureRandom.uuid}"
      obj.id_0 = ""
    end

    obj.id_0 << "_#{SecureRandom.uuid}"

    extent = model(:extent, 
                   {
                     :number => (rec['Extent'] ? rec['Extent'].to_s : nil),
                     :extent_type => get_extent_type(rec['ExtentUnitID']),
                     :portion => unspecified('whole')
                   })

    obj.extents = [extent]

    date =  model(:date,
                  {
                    :expression => get_date_expression(rec),
                    :date_type => 'inclusive',
                    :label => unspecified('creation')
                  })

    dbegin = rec['NormalDateBegin']
    dend = rec['NormalDateEnd']

    if dbegin && dend && (dbegin > dend)
      $log.warn("Throwing out nonsensical Date fields, begin: #{dbegin}; end: #{dend}")
    else
      date.begin = dbegin
      date.end = dend
    end

    obj.dates << date

    if rec['PredominantDates']
      obj.dates << model(:date,
                         {
                           :expression => rec['PredominantDates'],
                           :date_type => 'bulk',
                           :label => unspecified('creation')
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

    if rec['AcquisitionDate']
      obj.dates << model(:date,
                         {
                           :expression => "Date acquired: #{rec['AcquisitionDate']}",
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

    if rec.has_key?('Languages') && rec['Languages'][0]
      obj.language = rec['Languages'][0]
    end


    if rec['AltExtentStatement']
      obj.extents << model(:extent,
                           {
                             :number => rec['AltExtentStatement'],
                             :portion => 'whole',
                             :extent_type => 'other_unmapped'
                           })
    end


    note_mappings.each do |map|

      joint = map[:joint] ? map[:joint] : " "
      content = if map[:archon_type].is_a?(Array)
                  map[:archon_type].map{|key| rec[key]}.compact.join(joint)
                else
                  rec[map[:archon_type]]
                end

      next if content.nil? || content.empty?

      obj.notes << model(:note_multipart,
                         {
                           :type => map[:note_type],
                           :label => map[:label],
                           :subnotes => [model(:note_text,
                                            {
                                              :content => content
                                            })]
                         })

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


  def self.note_mappings
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

     {:archon_type => %w(OrigCopiesNote OrigCopiesURL RelatedMaterialsURL), 
       :note_type => 'originalsloc', 
       :label => 'Existence and Location of Originals'},

     {:archon_type => %w(OtherNote OtherURL), 
       :note_type => 'odd', 
       :label => "Other Descriptive Information"},

     {:archon_type => %w(BiogHist BiogHistAuthor),
       :note_type => 'bioghist',
       :label => "Biographical or Historical Information",
       :joint => "Note written by "
     }

    ]
  end
end
