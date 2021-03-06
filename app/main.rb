
unless RUBY_VERSION =~ /1\.9\.3/
  puts "You are using an unsupported version of Ruby. Please read the README and try again"
  raise "Cannot support #{RUBY_VERSION}"
end

require 'sinatra'
require 'sinatra/assetpack'

require_relative 'lib/startup'
require_relative 'lib/migrate'

Appdata.mode = :server
Appdata.app_dir = File.dirname(__FILE__)

class MigrationService < Sinatra::Base
  set :port, Appdata.port_number
  set :root, File.dirname(__FILE__)
  set :show_exceptions, :after_handler

  register Sinatra::AssetPack
  assets {
    serve '/css',  from: 'css'
    serve '/js/', from: 'js'

    ignore '*-min.css'

    css :application,  [
                        '/css/pure/*.css',
                        '/css/main.css'
                       ]

    js :app, [
              'js/vendor/jquery-2.0.3.min.js',
              'js/vendor/jquery.form.js',
              'js/vendor/jquery.validate.js',
              'js/main.js'
             ]
  }

  Dir.glob(File.dirname(File.absolute_path(__FILE__)) + '/lib/*.rb').each do |f|
    require f
  end

  public_dir = File.dirname(File.absolute_path(__FILE__)) + '/public'
  Dir.mkdir(public_dir) unless File.exists?(public_dir)


  get '/' do
    $busy ||= Atomic.new(false)
    if $busy.value
      erb :busy
    else
      erb :index
    end
  end


  post '/jobs' do
    $busy ||= Atomic.new(false)
    raise "BUSY" if $busy.value
    $busy.value = true
    
    $log.debug("POST /jobs with params: #{params.inspect}")

    Enumerator.new do |y|
      begin
        stamp = Time.now.strftime("%Y-%m-%d-%H-%M-%S")
        logfile = File.new(Appdata.app_dir + "/public/log-#{stamp}.txt", 'w')
        syslog = Logger.new(logfile)
        # todo - separate logs per thread to support
        # parallel jobs
        $log = MigrationLog.new(y, syslog)
        y << JSON.generate({
                             :type => :log, 
                             :file => File.basename(logfile.path)
                           }) + "---\n"

        m = MigrationJob.new(params[:job])
        m.migrate(y)
      rescue JSONModel::ValidationException => e
        body = "Errors: #{e.errors.to_s}"
        if e.respond_to?(:invalid_object)
          body << "<br />Offending record: [ #{e.invalid_object.to_s} ]"
        end
        y << JSON.generate({:type => :error, :body => body}) + "---\n"
      rescue Exception => e
        $log.debug("Server Error: "+e.to_s)
        $log.debug(e.backtrace)
        y << JSON.generate({:type => :error, :body => e.to_s}) + "---\n"
      ensure
        $log = syslog
        $log.close
        $busy.value = false
      end
    end
  end
end
