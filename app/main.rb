require 'sinatra'
require 'sinatra/assetpack'

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
  p request.params

  archon_params = params['job'].select{ |p| p =~ /archon/ }
  archon = ArchonConnection.new(archon_params)
  
  @archon_status = archon.status

  erb :"jobs/results"
  # do the long job
end

