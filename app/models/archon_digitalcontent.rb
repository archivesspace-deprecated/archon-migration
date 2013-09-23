Archon.record_type(:digitalcontent) do
  plural 'digitalcontent'
  no_html 'Title'


  def self.transform(rec)
    obj = to_digital_object(rec)

    yield obj
  end


  def self.to_digital_object(rec)
    digital_object_id = if rec['Identifier']
                          rec['Identifier']
                        else
                          "Archon ID: #{rec['ID']}"
                        end

    obj = model(:digital_object,
                {
                  :external_ids => [{
                                      :external_id => rec['ID'],
                                      :source => "archon"
                                    }],
                  :digital_object_id => digital_object_id,
                  :title => rec['Title'],
                  :publish => (rec['Browsable'] == '1' ? true : false),
                  
                })

    obj.uri = obj.class.uri_for(rec.import_id)

    {
      'Scope' => 'summary',
      'PhysicalDescription' => 'physical_description',
      'Publisher' => 'other_unmapped',
      'Contributor' => 'note',
      'RightsStatement' => 'userestrict',
    }.each do |field, note_type|
      if rec[field]
        prefix = %w(Publisher Contributor).include?(field) ? "#{field}: " : ""

        obj.notes << model(:note_digital_object,
                           {
                             :type => note_type,
                             :content => [prefix + rec[field]]
                           })
      end
    end

    if rec['Date']
      obj.dates << model(:date,
                         {
                           :expression => rec['Date'],
                           :date_type => 'single',
                           :label => 'creation'
                         })
    end

    if rec['ContentURL']

      obj.file_versions << model(:file_version,
                                 {
                                   :file_uri => rec['ContentURL']
                                 })

    end

    obj
  end
end
