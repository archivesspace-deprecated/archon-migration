require_relative 'archon_client'

module Archon
  @record_types = {}
  

  def self.record_type(key, &block)
    if block_given?
      @record_types[key] = Class.new(ArchonRecord, &block)
    else
      @record_types[key]
    end
  end


  class ArchonRecord

    # needs pagination
    def self.each
      result_set = ArchonClient::HTTP.get_json(endpoint)
      result_set.each {|k, v| yield k, v }
    end


    def self.endpoint
      "?p=#{@p}&batch_start=1"
    end

  end
    
end


Archon.record_type(:subject) do
  
  @p = 'core/subjects'

end
