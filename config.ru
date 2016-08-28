require 'sinatra'

set :run, false
set :environment, :production

require File.join(File.dirname(__FILE__), 'app')
