# Lookup Lists
[
 :subjectsource,
 :creatorsource,
 :extentunit,
 :materialtype
].each do |enum_type|
  Archon.record_type(enum_type) do
    plural enum_type.to_s << 's'
    include  Archon::EnumRecord
  end
end
