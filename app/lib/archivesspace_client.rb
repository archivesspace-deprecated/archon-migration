require_relative 'startup'
gem 'json-schema', '= 1.0.10'
require 'json-schema'
require_relative 'aspace_monkey_patches'

module ArchivesSpace
  @@initialized ||= false

  def self.init
    $log.warn("Already initiaized ArchivesSpace") if @@initialized

    ctools_path = File.dirname(__FILE__) + "/../../vendor/archivesspace/client_tools/#{Appdata.aspace_version}/"

    unless File.exists?(ctools_path)
      raise "Missing client libraries for ASpace #{Appdata.aspace_version}"
    end

    $:.unshift ctools_path

    ArchivesSpacePatches.patch_in do 
      require 'common/jsonmodel'
      require 'common/jsonmodel_client'
      require 'migrations/lib/parse_queue'
      require 'migrations/lib/jsonmodel_wrap'
      require 'migrations/lib/utils'
    end
    JSONModel.init(:client_mode => false, :enum_source => nil)
    @@initialized = true
  end


  def self.initialized?
    @@initialized
  end


  module HTTP

    def init_session(triesleft = 20)
      $log.debug("Attempt logging into ArchivesSpace")
      Thread.current[:backend_session] = nil

      url = URI("#{@url}/users/#{@user}/login")
      raise URIException, "URI format error: #{@url}" unless URI::HTTP === url

      req = Net::HTTP::Post.new(url.request_uri)
      req.form_data = {:password => @password}

      response = JSONModel::HTTP.do_http_request(url, req)
      unless response.code == '200'
        if triesleft > 0
          $log.debug("Log in failed: try again in 1 second")
          sleep(1)
          init_session(triesleft - 1)
        else
          raise "Giving up: couldn't log into ArchivesSpace and start a session"
        end
      end

      json = JSON::parse(response.body)
      @session = json['session']

      # for JSONModel
      Thread.current[:backend_session] = @session
      $log.debug("New backend session: #{@session}")
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

    def initialize(opts = {})
      @url = opts[:url] || Appdata.default_aspace_url
      @user = opts[:user] || Appdata.default_aspace_user
      @password = opts[:password] || Appdata.default_aspace_password

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


    def repo(id)
      JSONModel.set_repository(id)
      self
    end

    # rely on client tools to break when uris don't exist
    def database_empty? 
      begin 
        response = get_json('/repositories/2')
        return false
      rescue NoMethodError
        return true
      end
    end


    def import(y)

      client_block = Proc.new{ |msg| normalize_message(msg) do |normaled|
          y << json_chunk(normaled)
        end
      }

      reader = ResponseReader.new
      cache = ASpaceImport::ImportCache.new(
                                            :dry => false,
                                            :log => $log,
                                            :client_block => client_block
                                            )
      save_map = nil


      yield cache

      # don't bother with empty sets:
      # (another workaround of aspace migration tools,
      # this is the only way to confirm the set is empty)
      internal_batch = cache.instance_variable_get(:@batch)
      # seen_records = internal_batch.instance_variable_get(:@seen_records)
      working_file = internal_batch.instance_variable_get(:@working_file)

      # if cache.empty? && seen_records.empty?
      if cache.empty? && working_file.size == 0
        $log.warn("Empty batch: not saving")
        return {}
      end

      # save the batch
      $log.debug("Posting import batch")

      init_session # log in before posting a batch
      $log.debug("Using session: #{Thread.current[:backend_session]}")

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
              $log.debug("JSON parse error parsing chunk #{chunk}")
              y << json_chunk({
                               :type => 'error',  
                               :body => e.to_s
                             })
              return false
            end
          end

        else
          y << json_chunk({
                            :type => 'error',
                            :body => "ArchivesSpace server error: #{response.code}"
                          })
          return false
        end
      end

      return save_map
    end


    def prepare_map(save_response)
      # Hash {Archon_id => ASpace_uri}
      Hash[save_response.map {|k,v| [k.sub(/.*\//,''), v[0]]}]
    end


    def normalize_message(message)
      if message['errors'] && message['errors'].is_a?(Array)
        message['errors'].each do |error|
          yield ({:type => 'error', :source => 'aspace', :body => error})
        end
      elsif message['saved'] && message['saved'].is_a?(Hash)
        r = {
          :type => 'update',
          :source => 'aspace',
          :body => "Saved #{message['saved'].keys.count} records"
        }
        yield r

      elsif message['status'].respond_to?(:length)
        message['status'].each do |status|
          if status['type'] == 'started'
            r =  {            
              :source => 'aspace',
              :body => status['label'],
              :id => status['id']
            }
            r[:type] = r[:body] =~ /^Saved/ ? :update : :flash
            yield r
          elsif status['type'] == 'refresh'
            r = {
              :type => 'flash',
              :source => 'migration',
              :body => status['label'],
            }
            yield r
          end
        end
      elsif message['ticks']
        r =  {
          :type => 'progress',
          :source => 'aspace',
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
        s = @fragments.sub(/\n\Z/, '')
        @fragments = ""
        yield ASUtils.json_parse(s)
      elsif chunk =~ /.*,\n\Z/
        s = @fragments + chunk.sub(/,\n\Z/, '')
        @fragments = ""
        yield ASUtils.json_parse(s)
      else
        @fragments << chunk
      end
    end
  end
end

ArchivesSpace.init unless ArchivesSpace.initialized?
