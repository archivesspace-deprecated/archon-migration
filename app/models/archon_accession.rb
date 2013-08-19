Archon.record_type(:accession) do
  plural 'accessions'
  corresponding_record_type :accession

  def self.transform(rec)
    obj = super
    
    obj.publish = rec['Enabled'] == '1' ? true : false

    yield obj
  end  

end
