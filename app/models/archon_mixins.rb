module GenericArchivalObject
  def self.included(base)
    base.extend(ClassMethods)
  end


  module ClassMethods

    def transform(rec)
      obj = super

      if rec['MaterialTypeID']
        type = Archon.record_type(:materialtype).find(rec['MaterialTypeID'])
        obj.resource_type = type['MaterialType']
      end

      rec['Locations'].each do |loc|
        location = model(:location,
                         {
                           :coordinate_1_indicator => loc['RangeValue'],
                           :coordinate_1_label => 'Range',
                           :coordinate_2_indicator => loc['Section'],
                           :coordinate_2_label => 'Section',
                           :coordinate_3_indicator => loc['Shelf'],
                           :coordinate_3_label => 'Shelf',
                           :building => loc['Location']
                         })

        container = model(:container,
                          {
                            :type_1 => 'other',
                            :indicator_1 => loc['Content'],
                            :locations => [location]
                          })

        obj.instances << model(:instance,
                               {
                                 :container => container,
                                 :instance_type => 'text'

                               })
      end


      obj
    end

  end
end
