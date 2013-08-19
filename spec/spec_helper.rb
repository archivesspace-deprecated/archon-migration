require 'rspec'
require_relative '../app/lib/startup'
require_relative '../app/lib/archon_client'
require_relative '../app/lib/archivesspace_client'
require_relative '../app/lib/migrate'


def get_archon_client
  begin
    Archon::Client.new
  rescue Archon::ArchonAuthenticationError
    nil
  end
end


def get_aspace_client
  ArchivesSpace::Client.new
end


def nuke_aspace(client=nil)
  client = client ? client : get_aspace_client
  
  url = URI("#{Appdata.default_aspace_url}/")
  req = Net::HTTP::Delete.new(url.request_uri)

  response = JSONModel::HTTP.do_http_request(url, req)
  Thread.current[:backend_session] = nil
end


def verify_archon_dataset(client=nil)
  client = client ? client : get_archon_client
  if client
    repo = client.get_json('/?p=core/repositories&batch_start=1')
    unless repo['1']['Name'] == "Archon Migration Tracer"
      pending "an Archon instance running against the archon_tracer database"
    end
  else
    pending "an instance of Archon to run the test against"
  end
end


def get_subnotes_by_type(obj, note_type)
  obj['subnotes'].select {|sn| sn['jsonmodel_type'] == note_type}
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
