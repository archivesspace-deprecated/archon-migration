require 'rspec'
require_relative '../app/lib/startup'
require_relative '../app/lib/archon_client'
require_relative '../app/lib/archivesspace_client'


def get_archon_client
  Archon::Client.new(
                     :url => Appdata.default_archon_url,
                     :user => Appdata.default_archon_user,
                     :password => 'admin'
                     )

end
