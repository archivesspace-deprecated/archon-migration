module GenericArchivalObject
  def self.included(base)
    base.extend(ClassMethods)
  end


  def tap_locations
    unless self.has_key?('Locations')
      $log.warn(%{No 'Locations' data found for Archon record: #{self.inspect}})
      return nil
    end

    self['Locations'].each do |loc|
      location = self.class.transform_location(loc)


      container_location = self.class.model(:container_location,
                                            {
                                              :status => 'current',
                                              :start_date => '1999-12-31',
                                              :ref => location.uri
                                            })

      # n.b. aspace backend bug
      container_location.jsonmodel_type = nil

      container = self.class.model(:container,
                        {
                          :type_1 => 'other',
                          :indicator_1 => loc['Content'],
                          :container_locations => [container_location]
                        })

      instance = self.class.model(:instance,
                        {
                          :container => container,
                          :instance_type => 'text'
                        })

      yield location, instance
    end
  end



  module ClassMethods

    def transform(rec)
      obj = super

      if rec['MaterialTypeID']
        type = Archon.record_type(:materialtype).find(rec['MaterialTypeID'])
        obj.resource_type = type ? type['MaterialType'] : unspecified("unknown")
      end

      obj
    end

 
    def transform_location(loc)

      obj = model(:location).new
      obj.building = loc['Location']

      loc_keys = %w(RangeValue Section Shelf)
      i = 1
      loc_keys.each do |k|
        if loc[k]
          obj["coordinate_#{i}_indicator"] =  loc[k]
          obj["coordinate_#{i}_label"] = k
          i += 1
        end
      end

      #fallback
      unless obj.coordinate_1_indicator
        obj.coordinate_1_indicator = "not recorded"
        obj.coordinate_1_label = "RangeValue"
      end
      
      obj
    end
  end
end
