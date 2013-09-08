# -*- coding: utf-8 -*-
require_relative 'startup'
require 'net/http/persistent'
require 'json'
require 'lrucache'

module Archon

  @@record_types = {}

  def self.record_type(key, &block)
    if block_given?
      @@record_types[key] = Class.new(ArchonRecord, &block)
      @@record_types[key].instance_variable_set(:@key, key)
      @@record_types[key].set_type(key)
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

      def no_html(*fields)
        @no_html = fields
      end
        
    end
  end


  module EnumLookupHelpers

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def get_extent_type(id)
        rec = Archon.record_type(:extentunit).find(id)
        rec ? rec['ExtentUnit'] : unspecified("unknown")
      end

      def get_processing_priority(id)
        rec = Archon.record_type(:processingpriority).find(id)
        rec ? rec['ProcessingPriority'] : nil
      end

      def get_container_type(id)
        rec = Archon.record_type(:containertype).find(id)
        rec ? rec['ContainerType'] : nil
      end

    end
  end


  class ArchonRecord
    include RecordSetupHelpers
    include EnumLookupHelpers
    @@cache = LRUCache.new(:max_size => 1000, :default => false)

    def self.each(instantiate=true)
      raise NoArchonClientException unless Thread.current[:archon_client]

      i = 1
      loop do
        result_set = Thread.current[:archon_client].get_json(endpoint(i))
        result_size = nil
        if result_set.is_a?(Array)
          if result_set.length == 2 && result_set[1].empty?
            result_size = result_set[0].count
            result_set[0].each do |i, rec|
              yield (instantiate ? self.new(rec) : rec)
            end
          else
            result_size = result_set.count
            result_set.each do |rec|
              yield (instantiate ? self.new(rec) : rec)
            end
          end
        elsif result_set.is_a?(Hash)
          result_size = result_set.values.count
          result_set.each do |i, rec| 
            yield (instantiate ? self.new(rec) : rec)
          end
        elsif result_set.nil?
          $log.warn("No results found at: #{endpoint(i)}")
          break
        else
          raise "Unintelligible data structure #{result_set.inspect}"
        end
        break if result_size < 100 
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


    def self.set_type(type)
      @type = type
      @type_hash = @type.hash
    end


    def self.get_type
      @type
    end


    def self.unfound(id = '0')
      loglevel = case @type
                 when  :subjectsource, :creatorsource, :extentunit, :filetype, :materialtype, :containertype, :processingpriority 
                   :debug
                 else
                   :warn
                 end

      $log.send(loglevel, "Couldn't find a #{@type} with the ID: #{id}")
      nil
    end


    def self.find(id)
      import_id = import_id_for(id)
      if @@cache[import_id].nil?
        return unfound(id)
      end

      if @@cache[import_id]
        $log.debug("Found cached record: #{@@cache[import_id].inspect}")
        return @@cache[import_id]
      else

        id = id.to_s
        return unfound if id == '0'

        each(false) do |data|
          if data["ID"] == id
            @@cache[import_id] = self.new(data)
            return @@cache[import_id]
          end
        end
      
        @@cache[import_id] = nil
        return unfound(id)
      end
    end


    def self.filter(data)
      if @no_html
        @no_html.each do |field|
          if data.has_key?(field)
            data[field] = strip_html(data[field])
          end
        end
      end
      
      data
    end


    def self.model(type, data = nil)
      model = ASpaceImport.JSONModel(type)
      if data
        model.from_hash(data, false)
      else
        model
      end
    end


    def self.transform(rec)
      to_obj(rec)
    end


    def self.to_obj(rec)
      if @aspace_record_type
        obj = ASpaceImport.JSONModel(@aspace_record_type).new
        if obj.respond_to?(:uri) && rec.import_id
          obj.uri = obj.class.uri_for(rec.import_id)
        end

        obj
      else
        raise "error"
      end
    end


    def self.unspecified(value)
      $log.debug("Using unspecified value: #{value}")
      value
    end


    def self.strip_html(val)
      val.gsub(%r{</?[^>]+?>}, '')
    end


    def self.name_template(rec=nil, extra_vals=nil)
      hsh = {
        :name_order => unspecified('direct'),
        :sort_name_auto_generate => true,
      }
      if rec && rec['Identifier']
        hsh.merge!(:authority_id => rec['Identifier'])
      end

      if extra_vals
        hsh.merge!(extra_vals)
      end

      hsh
    end


    def self.import_id_for(id)
      raise "No @type_hash variable" unless @type_hash
      "import_#{@type_hash}-#{id}"
    end


    def initialize(data)
      @data = self.class.filter(data)
    end


    def import_id
      self.class.import_id_for(self['ID'])
    end


    def [](key)
      unless @data.has_key?(key)
        $log.debug("DATA: #{@data}")
        raise "Bad key (#{key}) used to access Archon -#{@type}- data"
      end
      val = @data[key]
      unless val && val.to_s.empty? && val.is_a?(String)
        val
      else
        nil
      end
    end


    def has_key?(k)
      @data.has_key?(k)
    end


    def pp
      @data.each do |k,v|
        p "#{k}: #{v}"
      end

      nil
    end
  end


  module HTTP

    def http
      @http ||= Net::HTTP::Persistent.new 'archon_client'
      @http.read_timeout = 1200
      @http
    end


    def get_json(endpoint)
      @http_cache ||= LRUCache.new(:max_size => 50, :default => false)

      unless @http_cache[endpoint]
        _get_json(endpoint)
      end
        
      @http_cache[endpoint]
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


    def download_bitstream(endpoint, filepath)
      
      uri = URI.parse("#{@url}#{endpoint}")
      $log.debug("Prepare Archon request: #{uri.request_uri}")

      req = Net::HTTP::Get.new(uri.request_uri)
      http_request(uri, req) do |response|
        if response.code != '200'
          raise "ERROR Getting bitstream #{response.inspect}"
        else
          begin
            file = File.open(filepath, "w")
            response.read_body do |chunk|
              file.write(chunk)
            end
          ensure
            file.close unless file.nil?
          end
        end
      end
    end
      

    def http_request(uri, req, &block)
      session = current_archon_session

      req['SESSION'] = session
      req['COOKIE'] = "archon=#{session}"

      req.basic_auth("admin", "admin")
      response = http.request(uri, req, &block)

      response
    end


    def current_archon_session      
      init_session unless @session
      @session
    end


    def init_session
      $log.debug("Logging into Archon")
      uri = URI.parse(@url + "/?p=core/authenticate")
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


    def _get_json
      uri = URI.parse("#{@url}#{endpoint}")
      $log.debug("Prepare Archon request: #{uri.request_uri}")

      req = Net::HTTP::Get.new(uri.request_uri)
      response = http_request(uri, req)
      $log.debug("Raw Archon response : #{response.inspect}")
      if response.code != '200'
        raise "ERROR Getting JSON #{response.inspect}"
      else
        begin
          json = JSON.parse(response.body)
          json
        rescue JSON::ParserError
          $log.debug(response.body)
          if response.body.match(/No matching record\(s\) found/)
            return nil
          else
            raise "Archon response is not JSON!"
          end
        end
      end
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
