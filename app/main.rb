require 'sinatra'
require 'sinatra/assetpack'

require_relative 'lib/startup'
require_relative 'lib/migrate'

set :port, 4568
 
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

  m = MigrationWorker.new(params[:job])

  m.migrate

  @archon_status = "ok"

  erb :"jobs/results"
  # do the long job
end

