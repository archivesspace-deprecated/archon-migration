require 'rspec'
require_relative '../app/lib/startup'
require_relative '../app/lib/archon_client'
require_relative '../app/lib/archivesspace_client'


def get_archon_client
  begin
    Archon::Client.new(
                       :url => Appdata.default_archon_url,
                       :user => Appdata.default_archon_user,
                       :password => 'admin'
                       )
  rescue Archon::ArchonAuthenticationError
    nil
  end

end


class MockEnumSource
  def self.valid?(enum_name, value)
    [true, false].sample
  end

  def self.values_for(enum_name)
    %w{alpha beta epsilon}
  end
end


class MockArchivesSpaceClient
  attr_reader :enum_source

  def initialize
    @enum_source = MockEnumSource
  end
end
