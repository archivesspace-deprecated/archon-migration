# Lookup Lists
[
 :subjectsource,
 :creatorsource,
 :extentunit,
 :filetype,
 :materialtype,
 :containertype,
 :processingpriority 
].each do |enum_type|
  Archon.record_type(enum_type) do
    pl = case enum_type
         when :processingpriority; 'processingpriorities'
         else; enum_type.to_s << 's'
         end
    plural pl
    include  Archon::EnumRecord
  end
end


Archon.record_type(:language) do
  
  def self.endpoint
    '/packages/core/lib/languages.json'
  end

  def self.find(id)
    id = id.to_s

    archon_records = Thread.current[:archon_client].get_json(endpoint)

    if archon_records.has_key?(id)
      self.new(archon_records[id])
    else
      nil
    end
  end
end
