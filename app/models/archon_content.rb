Archon.record_type(:content) do
  plural 'content'
  no_html 'Title'

  def self.endpoint(start = 1)
    raise "Collection not specified" unless @cid
    "/?p=#{path}&batch_start=#{start}&cid=#{@cid}"
  end


  def self.set(collection_id)
    @cid = collection_id.to_s
    raise "Argument error" unless @cid =~ /[0-9]+/
    self
  end


  def each_instance
    self.each do |rec|
      yield obj if rec['ContentType'] == '2'
    end
  end


  def self.transform(rec)
    case rec['ContentType']
    when '1'
      yield to_archival_object(rec)
    when '2'
      yield to_container_data(rec)
    when '3'
      yield to_archival_object(rec)
      yield to_container_data(rec)
    end
  end


  def self.to_archival_object(rec)
    obj = model(:archival_object).new
    obj.uri = obj.class.uri_for(rec.import_id)
    obj.key = rec['ID']

    obj.level = rec['EADLevel']
    obj.title = rec['Title']

    unless rec['ParentID'] == '0'
      real_parent_id = nearest_non_physical_ancestor(rec['ParentID'])
      if real_parent_id.nil?
        $log.warn(%{Bad foreign key: can't locate the record associated with 'ParentID' in this record: #{rec.inspect}})
      elsif real_parent_id == '0'
        $log.warn("An intellectual Content record with a physical Content record as its parent is being placed at the top level of the resource hierarchy")        
      else
        obj.parent = {
          :ref => obj.class.uri_for(rec.class.import_id_for(real_parent_id))
        }
      end
    end

    resource_id = Archon.record_type(:collection).import_id_for(@cid)
    resource_uri = ASpaceImport.JSONModel(:resource).uri_for(resource_id)
    obj.resource = {:ref => resource_uri}

    if rec['PrivateTitle']
      obj.notes << model(:note_singlepart,
                         {
                           :type => 'materialspec',
                           :label => 'Private Title',
                           :publish => false,
                           :content => [rec['PrivateTitle']]
                         })
    end


    if rec['Date']
      obj.dates << model(:date,
                         {
                           :expression => rec['Date'],
                           :date_type => 'single',
                           :label => 'creation'
                         })
    end


    if rec['Description']
      obj.notes << model(:note_multipart,
                         {
                           :type => 'scopecontent',
                           :subnotes => [model(:note_text,
                                              {
                                                :content => rec['Description']
                                               })]
                         })
    end

    obj.publish = rec['Enabled'] == '1' ? true : false
    

    if rec['SortOrder']
      obj.position = rec['SortOrder'].to_i
    end

    if rec['UniqueID']
      obj.component_id = rec['UniqueID']
    end

    if rec['OtherLevel'] && obj.level == 'otherlevel'
      obj.other_level = rec['OtherLevel']
    end


    unless rec['Notes'].is_a?(Array) && rec['Notes'].empty?
      rec['Notes'].values.each do |note_data|
        model_type, note_type  = determine_note_type(note_data['NoteType'])

        content_hash =  case model_type
                        when :note_multipart
                          {:subnotes => [model(:note_text,
                                               {
                                                 :content => note_data['Content']
                                               })]}
                        when :note_singlepart
                          {:content => [note_data['Content']]}
                        end

        note = model(model_type,
                     {
                       :label => note_data['Label'],
                       :type => note_type
                     }.merge(content_hash))

        
        obj.notes << note
      end
    end

    unless obj.title || obj.dates.count > 0
      $log.warn(%{Assigning a random title to the archival_object record created from Archon record #{rec.inspect}})
      obj.title = "migration_#{SecureRandom.uuid}"
    end

    obj
  end


  def self.to_container_data(rec)
    data_key = case rec['ContentType']
               when '2'; rec['ParentID']
               when '3'; rec['ID']
               end

    [data_key, {
       :type => get_container_type(rec['ContainerTypeID']),
       :indicator => rec['ContainerIndicator']
     }]
  end


  def self.nearest_non_physical_ancestor(parent_id)
    parent = find(parent_id)

    return nil if parent.nil?

    if parent['ContentType'] == '2'
#      raise "tree error" if parent['ParentID'] == '0'
      return '0' if parent['ParentID'] == '0'
      nearest_non_physical_ancestor(parent['ParentID'])
    else
      parent_id
    end
  end


  def self.determine_note_type(archon_type)
    case archon_type
    when "accessrestrict", "accruals", "acqinfo", "altformavail", "appraisal", "arrangement", "bioghist", "custodhist", "dimensions", "originalsloc", "prefercite", "processinfo", "relatedmaterial", "separatedmaterial", "userestrict"
      [:note_multipart, archon_type]
    when "origination", "langmaterial", "note", "unitid", "odd"
      [:note_multipart, "odd"]
    when "extent"
      [:note_singlepart, "physdesc"]
    when "materialspec", "physdesc", "physfacet"
      [:note_singlepart, archon_type]
    else
      [:note_multipart, "odd"] # ????
    end
  end
end
