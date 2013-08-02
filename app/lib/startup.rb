# Instantiate application run environment
require 'rubygems'
require 'logger'

$log = Logger.new(STDOUT)

# TODO: load separate config file:
ASPACE_VERSION = 'v0.6.2'

class URIException < StandardError
end



