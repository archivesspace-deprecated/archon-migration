Archon.record_type(:digitalfile) do
  self.plural 'digitalfiles'

  def self.transform(rec)
    obj = to_digital_object_component(rec)
    
    yield obj
  end


  def self.to_digital_object_component(rec)
    obj = model(:digital_object_component).new
    obj.uri = obj.class.uri_for(rec.import_id)

    obj.label = rec['Title']

    if rec['Filename']
      fv = model(:file_version).new
      fv.file_uri = @base_url ? "#{@base_url}/#{rec['Filename']}" : rec['Filename']
      if rec['FileTypeID']
        ft = Archon.record_type(:filetype).find(rec['FileTypeID'])
        fv.file_format_name = ft['FileType']
      end
      obj.file_versions << fv
    end

    if rec['DisplayOrder']
      obj.position = rec['DisplayOrder'].to_i
    end

    raise "Bad ID" unless rec['DigitalContentID'] && rec['DigitalContentID'] != '0'

    doid = Archon.record_type(:digitalcontent).import_id_for(rec['DigitalContentID'])
    obj.digital_object = {
      :ref => ASpaceImport.JSONModel(:digital_object).uri_for(doid)
    }

    obj
  end


  def self.base_url=(base)
    @base_url = base
  end

end
