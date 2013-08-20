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

      obj
    end

  end
end
