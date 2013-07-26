require 'net/http/persistent'
require 'json'

module ArchonClient

  module HTTP

    @archon_url = "http://localhost/archon/"


    def self.http
      @http ||= Net::HTTP::Persistent.new 'archon_client'
      @http.read_timeout = 1200
      @http
    end


    def self.get_json(endpoint)
      uri = URI.parse("#{@archon_url}#{endpoint}")

      req = Net::HTTP::Get.new(uri.request_uri)
      response = http_request(uri, req)

      if response.code != '200'
        raise "ERROR Getting JSON #{response.inspect}"
      else
        json = JSON.parse(response.body)

        json
      end
    end


    def self.http_request(uri, req, &block)
      archon_session = current_archon_session

      req['SESSION'] = current_archon_session
      req['COOKIE'] = "archon=#{current_archon_session}"

      req.basic_auth("admin", "admin")
      response = http.request(uri, req)

      response
    end


    def self.current_archon_session      
      init_session unless Thread.current[:archon_session]
      Thread.current[:archon_session]
    end


    def self.init_session

      uri = URI.parse(@archon_url + "?p=core/authenticate&apilogin=admin&apipassword=admin")
      req = Net::HTTP::Get.new(uri.request_uri)
      
      response = http_request(uri, req)

      raise "Session Init error" unless response.code == '200'

      json = JSON::parse(response.body)

      Thread.current[:archon_session] = json['session']
    end

  end
end
      
