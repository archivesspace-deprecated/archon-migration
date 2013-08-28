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
                  :default_archon_password,
                  :default_aspace_url,
                  :default_aspace_user,
                  :default_aspace_password


Appdata.aspace_version                  'v0.6.2'

Appdata.port_number                     4568

Appdata.default_archon_url              'http://localhost/archon'

Appdata.default_archon_user             'admin'

Appdata.default_archon_password         'admin'

Appdata.default_aspace_url              'http://localhost:4567'

Appdata.default_aspace_user             'admin'

Appdata.default_aspace_password         'admin'


if File.exists?(File.join(File.dirname(__FILE__), 'config_local.rb'))
  require_relative('config_local.rb')
end
