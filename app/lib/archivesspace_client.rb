require_relative 'startup'
gem 'json-schema', '= 1.0.10'
require 'json-schema'
require_relative 'aspace_monkey_patches'

module ArchivesSpace

  def self.init
    $:.unshift File.dirname(File.absolute_path(__FILE__)) + "/../../vendor/archivesspace/client_tools/#{Appdata.aspace_version}/"

    require 'common/jsonmodel'
    require 'common/jsonmodel_client'
    require 'migrations/lib/parse_queue'
    require 'migrations/lib/jsonmodel_wrap'
    require 'migrations/lib/utils'
    ArchivesSpacePatches.patch

    JSONModel.init(:client_mode => false, :enum_source => nil)
  end


  module HTTP

    def init_session
      $log.debug("Logging into ArchivesSpace")
      url = URI("#{@url}/users/#{@user}/login")
      raise URIException, "URI format error: #{@url}" unless URI::HTTP === url

      req = Net::HTTP::Post.new(url.request_uri)
      req.form_data = {:password => @password}

      response = JSONModel::HTTP.do_http_request(url, req)
      raise "Session Init error" unless response.code == '200'

      json = JSON::parse(response.body)
      @session = json['session']

      # for JSONModel
      Thread.current[:backend_session] = @session
    end


    def get_json(uri)
      JSONModel::HTTP.get_json(uri)
    end


    def post_json(uri, json)
      url = URI("#{@url}#{uri}")
      JSONModel::HTTP.post_json(url, json)
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


    def json_chunk(ch)
      JSON.generate(ch) + "---\n"
    end


    def import(y)
      reader = ResponseReader.new
      cache = ASpaceImport::ImportCache.new(
                                            :dry => false,
                                            :log => $log
                                            )
      save_map = nil


      yield cache

      # save the batch
      $log.debug("Posting import batch")
      $log.debug(cache.inspect)
      cache.save! do |response|
        if response.code.to_s == '200'

          response.read_body do |chunk|
            begin
              reader.read(chunk) do |message|
                $log.debug("Raw ASpace response: #{message.inspect}")
                normalize_message(message) do |normaled|
                  y << json_chunk(normaled)
                end
                if message['saved']
                  save_map = prepare_map(message['saved'])
                end
              end
            rescue JSON::ParserError => e
              y < json_chunk({
                               :type => 'error',  
                               :body => e.to_s
                             })
            end
          end

        else
          y << json_chunk({
                            :type => 'error',
                            :body => "ArchivesSpace server error: #{response.code}"
                          })
        end
      end

      return save_map
    end


    def prepare_map(save_response)
      $log.debug("SR-Raw #{save_response}")

      # Hash {Archon_id => ASpace_id}
      Hash[save_response.map {|k,v| [k.sub(/.*\//,''), v[0]]}]

    end


    def normalize_message(message)
      if message['saved']
        r = {
          :type => 'status',
          :body => "Saved #{message['saved'].keys.count} records"
        }
        yield r

      elsif message['status'].respond_to?(:length)
        message['status'].each do |status|
          if status['type'] == 'started'
            r =  {
              :type => 'status',
              :body => status['label'],
              :id => status['id']
            }
            yield r
          end
        end
      elsif message['ticks']
        r =  {
          :type => 'progress',
          :ticks => message['ticks'],
          :total => message['total']
        }
        yield r
      else
        $log.debug("unhandled raw message: #{message.inspect}")
      end
    end
  end


  class ResponseReader
    def initialize
      @fragments = ""
    end


    def read(chunk)
      if chunk =~ /\A\[\n\Z/
        # do nothing because we're treating the response as a stream
      elsif chunk =~ /\A\n\]\Z/
        # the last message doesn't have a comma, so it's a fragment
        yield ASUtils.json_parse(@fragments.sub(/\n\Z/, ''))
      elsif chunk =~ /.*,\n\Z/
        yield ASUtils.json_parse(@fragments + chunk.sub(/,\n\Z/, ''))
      else
        @fragments << chunk
      end
    end
  end
end

ArchivesSpace.init
