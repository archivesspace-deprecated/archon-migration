Archon.record_type(:content) do
  plural 'content'

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
      obj.parent = {
        :ref => obj.class.uri_for(rec.class.import_id_for(real_parent_id))
      }
    end

    resource_id = Archon.record_type(:collection).import_id_for(@cid)
    resource_uri = ASpaceImport.JSONModel(:resource).uri_for(resource_id)
    obj.resource = {:ref => resource_uri}

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
    if parent['ContentType'] == '2'
      raise "tree error" if parent['ParentID'] == '0'
      nearest_non_physical_ancestor(parent['ParentID'])
    else
      parent_id
    end
  end
end
