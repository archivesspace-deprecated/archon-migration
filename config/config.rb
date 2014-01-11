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
                  :archon_page_cache_size,
                  :port_number,
                  :default_archon_url,
                  :default_archon_user,
                  :default_archon_password,
                  :default_aspace_url,
                  :default_aspace_user,
                  :default_aspace_password,
                  :mode,
                  :app_dir,
									:use_dbcache

Appdata.aspace_version                  'v1.0.0'

Appdata.port_number                     4568

Appdata.default_archon_url              'http://localhost/archon'

Appdata.default_archon_user             'admin'

Appdata.default_archon_password         'admin'

Appdata.default_aspace_url              'http://localhost:8089'

Appdata.default_aspace_user             'admin'

Appdata.default_aspace_password         'admin'

# Migration performance will be severely impacted if this 
# value is less than the number of Content records in the largest
# Collection, divided by 100. So, e.g., if you have a Collection
# with 50,000 Content records, set this to 500 if your server
# has sufficient memory
Appdata.archon_page_cache_size          400 

Appdata.use_dbcache											false




if File.exists?(File.join(File.dirname(__FILE__), 'config_local.rb'))
  require_relative('config_local.rb')
end
