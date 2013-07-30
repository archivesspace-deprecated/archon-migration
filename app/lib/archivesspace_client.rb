gem 'json-schema', '= 1.0.10'
require 'json-schema'
require_relative 'startup'

module ArchivesSpace


  def self.init

    $:.unshift File.dirname(File.absolute_path(__FILE__)) + "/../../vendor/archivesspace/client_tools/#{ASPACE_VERSION}/"

    Kernel.module_eval do
      alias_method :orig_require, :require
      
      def require(*args)
        begin 
          orig_require(*args)
        rescue LoadError => e
          $log.debug("Load Error Caught: #{e}")
          raise e unless e.to_s =~ /(config-distribution|java)$/
        end
      end
    end

    require 'common/jsonmodel'
    require 'common/jsonmodel_client'
    require 'migrations/lib/parse_queue'
    require 'migrations/lib/jsonmodel_wrap'
    require 'migrations/lib/utils'
    require_relative 'aspace_monkey_patches'

    JSONModel.init(:client_mode => false, :enum_source => nil)
  end


  module HTTP

    def init_session
      $log.debug("Logging into ArchivesSpace")
      uri = URI("#{@url}/users/#{@user}/login")
      req = Net::HTTP::Post.new(uri.request_uri)
      req.form_data = {:password => @password}

      response = JSONModel::HTTP.do_http_request(uri, req)
      raise "Session Init error" unless response.code == '200'

      json = JSON::parse(response.body)
      @session = json['session']

      # for JSONModel
      Thread.current[:backend_session] = @session
    end
  end


  class Client
    include HTTP
    
    attr_reader :enum_source

    def initialize(opts)
      @url = opts[:url]
      @user = opts[:user]
      @password = opts[:password]

      init_session

      Thread.current[:archivesspace_client] = self

      # for monkey-patched JSONModel
      Thread.current[:archivesspace_url] = @url
      @enum_source = JSONModel::Client::EnumSource.new
    end


    def has_session?
      @session ? true : false
    end


    def import
      cache = ASpaceImport::ImportCache.new(
                                            :dry => true,
                                            :log => $log
                                            )
      yield cache

      # save the batch
      $log.debug("Posting import batch")
      cache.save! do |response|
        response.read_body do |message|
          $log.debug(message)
        end
      end
    end

  end

end

ArchivesSpace.init
