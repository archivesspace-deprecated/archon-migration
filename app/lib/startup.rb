# Instantiate application run environment
require 'rubygems'
require 'logger'

$log = Logger.new(STDOUT)

require_relative '../../config/config'
require_relative 'exceptions'
