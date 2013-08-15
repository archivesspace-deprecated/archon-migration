require_relative 'startup'
require 'net/http/persistent'
require 'json'

module Archon

  @@record_types = {}
  
  def self.record_type(key, &block)
    if block_given?
      @@record_types[key] = Class.new(ArchonRecord, &block)
      @@record_types[key].instance_variable_set(:@key, key)
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


  module EnumRecord
    def self.included(base)
      base.extend(ClassMethods)
    end


    module ClassMethods
      def path
        "core/enums"
      end

      def endpoint(start = 1)
        "/?p=#{path}&enum_type=#{@plural}&batch_start=#{start}"
      end
    end
  end


  module RecordSetupHelpers
    def self.included(base)
      base.extend(ClassMethods)
    end


    module ClassMethods
      def plural(plural)
        @plural = plural
      end

      
      def corresponding_record_type(aspace_record_type)
        @aspace_record_type = aspace_record_type
      end
        
    end
  end
    

  class ArchonRecord
    include RecordSetupHelpers

    def self.each
      raise NoArchonClientException unless Thread.current[:archon_client]

      i = 1
      loop do
        result_set = Thread.current[:archon_client].get_json(endpoint(i))
        if result_set.is_a?(Array)
          result_set.each {|rec| yield self.new(rec)}
        elsif result_set.is_a?(Hash)
          result_set.each {|i, rec| yield self.new(rec) }
        else
          raise "Unintelligble data structure #{result_set.inspect}"
        end
        break if result_set.count < 100
        i += 100
        raise ArchonPaginationException, "Pagination Limit Exceeded" if i > 10000
      end
    end


    def self.path
      "core/#{@plural}"
    end


    def self.endpoint(start = 1)
      "/?p=#{path}&batch_start=#{start}"
    end


    def self.all
      all = []
      each { |rec| all << rec }

      all
    end


    def self.find(id)
      @cache ||= {}
      if @cache.has_key?(id)
        return @cache[id]
      end

      each do |rec|
        if rec["ID"] == id
          @cache[id] = rec 
          return @cache[id]
        end
      end
    end


    def self.model(type, data = nil)
      model = ASpaceImport.JSONModel(type)
      if data
        model.from_hash(data)
      else
        model
      end
    end


    def self.transform(rec)
      if @aspace_record_type
        obj = ASpaceImport.JSONModel(@aspace_record_type).new
        if obj.respond_to?(:uri) && rec["ID"]
          obj.uri = obj.class.uri_for(rec["ID"])
        end
        return obj
      end
    end


    def self.unspecified(value)
      $log.warn("Using unspecified value: #{value}")
      value
    end


    def self.name_template(rec)
    {
      :name_order => unspecified('direct'),
      :sort_name_auto_generate => true,
      :authority_id => rec['Identifier']
    }
    end


    def initialize(data)
      @data = data
    end


    def [](key)
      @data[key]
    end

    alias_method :mm_orig, :method_missing

    def method_missing(method, *args)
      if @data.has_key?(args[0])
        @data[args.shift]
      else
        mm_orig(method, *args)
      end
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
      $log.debug("Prepare Archon request: #{uri.request_uri}")

      req = Net::HTTP::Get.new(uri.request_uri)
      response = http_request(uri, req)
      $log.debug("Raw Archon response: #{response.inspect}")
      if response.code != '200'
        raise "ERROR Getting JSON #{response.inspect}"
      else
        begin
          json = JSON.parse(response.body)
          json
        rescue JSON::ParserError
          raise "Archon response is not JSON!"
        end
      end
    end


    def get_bitstream(endpoint)
      uri = URI.parse("#{@url}#{endpoint}")
      $log.debug("Prepare Archon request: #{uri.request_uri}")

      req = Net::HTTP::Get.new(uri.request_uri)
      response = http_request(uri, req)
      $log.debug("Raw Archon response: #{response.inspect}")
      if response.code != '200'
        raise "ERROR Getting bitstream #{response.inspect}"
      else
        response.body
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

    def initialize(opts = {})
      @url = opts[:url] || Appdata.default_archon_url

      @user = opts[:user] || Appdata.default_archon_user
      @password = opts[:password] || Appdata.default_archon_password

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
