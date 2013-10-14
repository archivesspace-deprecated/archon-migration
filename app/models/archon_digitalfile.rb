Archon.record_type(:digitalfile) do
  self.plural 'digitalfiles'

  @filenames = {}

  def self.transform(rec)
    obj = to_digital_object_component(rec)
    
    yield obj
  end


  def self.unique_filename(basename, id)
    @filenames[basename] ||= []

    i =  @filenames[basename].index(id)
    if i.nil?
      @filenames[basename] << id
      i = @filenames.length - 1
    end

    newname = if i == 0
                basename
              elsif basename.match(/\.[^.]+/)
                basename.sub(/\.(.*)/, '.' + i.to_s + '.\1')
              else
                "#{basename}.#{i}"
              end
    newname
  end


  def initialize(data)
    if data['Filename']
      data['Filename'] = self.class.unique_filename(data['Filename'], data['ID'])
    end

    super(data)
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

      if rec['Bytes']
        fv.file_size_bytes = rec['Bytes'].to_i
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
