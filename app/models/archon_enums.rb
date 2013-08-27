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
