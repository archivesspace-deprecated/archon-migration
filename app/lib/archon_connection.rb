require 'net/http/persistent'

class ArchonConnection 

  
  def get_session(opts)
    @http ||= Net::HTTP::Persistent.new 'archon_client'
    @http.read_timeout = 1200

    uri = URI("#{@archon_url}?p=core/authenticate")
    req = Net::HTTP::Get.new(url.request_uri)


  def initialize(opts)
    @archon_url = opts[:archon_url]
    @archon_user = opts[:archon_user]
    @archon_password = opts[:archon_user]
    @opts = opts
  end

  def status
    "connected?"
  end

end
