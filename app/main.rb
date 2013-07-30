require 'sinatra'
require 'sinatra/assetpack'

require_relative 'lib/startup'

set :root, File.dirname(__FILE__)
register Sinatra::AssetPack

assets {
  serve '/css',  from: 'css'

  ignore '*-min.css'

  css :application,  [
   '/css/pure/*.css'
  ]
}

Dir.glob(File.dirname(File.absolute_path(__FILE__)) + '/lib/*.rb').each do |f|
  p f
  require f
end


get '/' do
  erb :index
end

get '/jobs/new' do
  erb :"jobs/new"
end

post '/jobs' do
  $log.debug("POST /jobs with params: #{request.params.inspect}")

  m = MigrationController.new(request.params)

  m.migrate!

  @archon_status = "ok"

  erb :"jobs/results"
  # do the long job
end

