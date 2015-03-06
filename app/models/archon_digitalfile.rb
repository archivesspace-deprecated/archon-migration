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

    # need to remove special characters from filename
    sanitize_filename(newname)
  end


  # http://stackoverflow.com/questions/1939333/how-to-make-a-ruby-string-safe-for-a-filesystem
  def self.sanitize_filename(filename)
    # Split the name when finding a period which is preceded by some
    # character, and is followed by some character other than a period,
    # if there is no following period that is followed by something
    # other than a period (yeah, confusing, I know)
    fn = filename.split /(?<=.)\.(?=[^.])(?!.*\.[^.])/m

    # We now have one or two parts (depending on whether we could find
    # a suitable period). For each of these parts, replace any unwanted
    # sequence of characters with an underscore
    fn.map! { |s| s.gsub /[^a-z0-9\-]+/i, '_' }

    # Finally, join the parts with a period and return the result
    return fn.join '.'
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
