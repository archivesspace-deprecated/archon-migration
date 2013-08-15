Archon.record_type(:classification) do
  self.plural 'classifications'


  def self.transform(rec)

    json_type = rec['ParentID'] == '0' ? :classification : :classification_term

    data = {
      :identifier => rec['ClassificationIdentifier'],
      :title => rec['Title']
    }

    unless rec['ParentID'] == '0'
      classification_uri, parent_uri = walk_ancestry(rec)

      data.merge!({:classification => {:ref => classification_uri}})
      data.merge!({:parent => {:ref => parent_uri}}) if parent_uri
    end

    obj = model(json_type, data)
    obj.uri = obj.class.uri_for(rec['ID'])

    yield obj if block_given? 

    obj
  end


  def self.walk_ancestry(rec, parent_term_uri=nil, i=100)
    parent_id = rec['ParentID']
    raise "classification level too deep" if i == 0

    if parent_id == '0'
      return model(:classification).uri_for(rec['ID']), parent_term_uri
    else
      parent = Archon.record_type(:classification).find(parent_id)
      if parent_term_uri.nil? && parent['ParentID'] != '0'
        parent_term_uri =  model(:classification_term).uri_for(parent_id)
      end
      i -= 1
      walk_ancestry(parent, parent_term_uri, i)
    end
  end
end
