Archon.record_type(:digitalcontent) do
  self.plural 'digitalcontent'

  def self.transform(rec)
    obj = to_digital_object(rec)

    yield obj
  end


  def self.to_digital_object(rec)
    obj = model(:digital_object,
                {
                  :external_ids => [{
                                      :external_id => rec['ID'],
                                      :source => "archon"
                                    }],
                  :digital_object_id => rec['Identifier'],
                  :title => rec['Title'],
                  :publish => (rec['Browsable'] == '1' ? true : false),
                  
                })

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

    obj.dates << model(:date,
                       {
                         :expression => rec['Date'],
                         :date_type => 'single',
                         :label => 'creation'
                       })

    if rec['ContentURL']

      obj.file_versions << model(:file_version,
                                 {
                                   :file_uri => rec['ContentURL']
                                 })

    end

    obj
  end
end
