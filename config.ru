require 'rack'
require './app/main'

def app
  MigrationService
end

map "/" do
  run MigrationService
end