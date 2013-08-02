require 'sinatra'
require 'sinatra/assetpack'

require_relative 'lib/startup'
require_relative 'lib/migrate'

set :port, 4568
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


get '/' do
  erb :index
end


get '/jobs/new' do
  erb :"jobs/new"
end


post '/jobs' do
  $log.debug("POST /jobs with params: #{params.inspect}")

  Enumerator.new do |y|
    begin
      m = MigrationJob.new(params[:job])
      m.migrate(y)
    rescue Exception => e
      $log.debug("Error: "+e.to_s)
      y << JSON.generate({:type => :error, :body => e.to_s}) + "---\n"
    end
  end
end

