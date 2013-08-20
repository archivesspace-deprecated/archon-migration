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

      classific_id = nil
      if rec.has_key?['ClassificationID']
        classific_id = rec['ClassificationID']
      elsif rec.has_key?['Classifications']
        classific_id = rec['Classifications'][0] # !!!
      end
 
      if classific_id
        c = Archon.record_type(:classification).find(cid)
        c_uri = ASpaceImport.JSONModel(c.aspace_type).uri_for(c.import_id)
        obj.classification = {:ref => c_uri}
      end


      obj
    end

  end
end
