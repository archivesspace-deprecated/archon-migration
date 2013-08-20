Archon.record_type(:classification) do
  self.plural 'classifications'


  def self.transform(rec)

    obj = model(rec.aspace_type).new
    obj.identifier = rec['ClassificationIdentifier']
    obj.title = rec['Title']

    obj.uri = obj.class.uri_for(rec.import_id)

    if rec.aspace_type == :classification_term
      classification_uri, parent_uri = walk_ancestry(rec)
      obj.classification = {:ref => classification_uri}
      obj.parent = {:ref => parent_uri} if parent_uri
    end

    if rec['Description']
      obj.description = rec['Description']
    end

    yield obj if block_given? 

    obj
  end


  def self.walk_ancestry(rec, parent_term_uri=nil, i=100)
    parent_id = rec['ParentID']
    raise "classification level too deep" if i == 0

    if parent_id == '0'
      return model(:classification).uri_for(rec.import_id), parent_term_uri
    else
      parent = Archon.record_type(:classification).find(parent_id)
      if parent_term_uri.nil? && parent['ParentID'] != '0'
        parent_term_uri =  model(:classification_term).uri_for(parent.import_id)
      end
      i -= 1
      walk_ancestry(parent, parent_term_uri, i)
    end
  end


  def resource_identifiers(ids=nil)
    ids = [] unless ids
    ids.unshift(self['ClassificationIdentifier'])
    if self['ParentID'] == '0'
      return ids
    else
      self.class.find(self['ParentID']).resource_identifiers(ids)
    end
  end


  def aspace_type
    self['ParentID'] == '0' ? :classification : :classification_term
  end

end
