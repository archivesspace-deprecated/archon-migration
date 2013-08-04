module Appdata
  extend self

  def parameter(*names)
    names.each do |name|
      attr_accessor name

      define_method name do |*values|
        value = values.first
        value ? self.send("#{name}=", value) : instance_variable_get("@#{name}")
      end
    end
  end


  def config(&block)
    instance_eval &block
  end

end


Appdata.parameter :aspace_version, 
									:port_number,
					        :default_archon_url,
                  :default_archon_user,
                  :default_aspace_url,
                  :default_aspace_user


Appdata.aspace_version          'v0.6.2'

Appdata.port_number             4568

Appdata.default_archon_url      'http://localhost/archon'

Appdata.default_archon_user     'admin'

Appdata.default_aspace_url      'http://localhost:4567'

Appdata.default_aspace_user     'admin'
 
