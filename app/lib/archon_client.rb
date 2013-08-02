require_relative 'startup'
require 'net/http/persistent'
require 'json'

module Archon

  @@record_types = {}
  
  def self.record_type(key, &block)
    if block_given?
      @@record_types[key] = Class.new(ArchonRecord, &block)
    else
      @@record_types[key]
    end
  end


  def self.init
    Dir.glob(File.join(File.dirname(__FILE__),
                       '../',
                       'models', 
                       'archon_*.rb')).each do |file|
      load(file)
    end
  end


  class ArchonRecord

    # needs pagination
    def self.each
      result_set = Thread.current[:archon_client].get_json(endpoint)
      result_set.each {|k, v| yield k, v }
    end


    def self.endpoint
      "/?p=#{@p}&batch_start=1"
    end
  end


  module HTTP

    def http
      @http ||= Net::HTTP::Persistent.new 'archon_client'
      @http.read_timeout = 1200
      @http
    end


    def get_json(endpoint)
      uri = URI.parse("#{@url}#{endpoint}")

      req = Net::HTTP::Get.new(uri.request_uri)
      response = http_request(uri, req)
      $log.debug("Raw Archon response: #{response.inspect}")
      if response.code != '200'
        raise "ERROR Getting JSON #{response.inspect}"
      else
        json = JSON.parse(response.body)

        json
      end
    end


    def http_request(uri, req, &block)
      session = current_archon_session

      req['SESSION'] = session
      req['COOKIE'] = "archon=#{session}"

      req.basic_auth("admin", "admin")
      response = http.request(uri, req)

      response
    end


    def current_archon_session      
      init_session unless @session
#      Thread.current[:archon_session]
      @session
    end


    def init_session
      $log.debug("Logging into Archon")
      uri = URI.parse(@url + "/?p=core/authenticate&apilogin=admin&apipassword=admin")
      raise URIException, "URI format error: #{@url}" unless URI::HTTP === uri

      req = Net::HTTP::Get.new(uri.request_uri)
 
      req.basic_auth(@user, @password)
      response = http.request(uri, req)

      if response.code != '200' || response.body =~ /Authentication Failed/
        raise ArchonAuthenticationError, "Could not log in to Archon"
      end

      json = JSON::parse(response.body)
      @session = json['session']
    end
  end


  class Client
    include HTTP

    def initialize(opts)
      @url = opts[:url]

      @user = opts[:user]
      @password = opts[:password]

      init_session

      Thread.current[:archon_client] = self
    end


    def has_session?
      @session ? true : false
    end


    def record_type(key)
      Archon.record_type(key)
    end
  end


  class ArchonAuthenticationError < StandardError
  end

end

Archon.init
