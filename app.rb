require 'sinatra'
require 'eventmachine'
require 'sinatra/base'
require 'thin'
require 'em-twitter'
require 'json'
require 'sinatra-websocket'
require 'dotenv'
require 'tilt/erb'

Dotenv.load

$sockets = []

def run(opts)
  options = {
    path: '/1.1/statuses/filter.json',
    params: { track: 'sport' },
    oauth: {
      consumer_key: ENV['TWITTER_CONSUMER_KEY'],
      consumer_secret: ENV['TWITTER_CONSUMER_SECRET'],
      token: ENV['TWITTER_ACCESS_TOKEN'],
      token_secret: ENV['TWITTER_ACCESS_SECRET']
    }
  }

  EM.run do
    server = opts[:server] || 'thin'
    host = opts[:host] || '0.0.0.0'
    port = opts[:port] || '8080'
    web_app = opts[:app]

    dispatch = Rack::Builder.app do
      map '/' do
        run web_app
      end
    end

    unless %w(thin hatetepe goliath).include? server
      raise "Need an EM webserver, but #{server} isn't"
    end

    client = EM::Twitter::Client.connect(options)
    client.each do |status|
      EM.defer do
        hash = {}
        hash = JSON.parse(status)
        EM.next_tick { $sockets.each { |s| s.send(hash.inspect) } }
      end
    end

    Rack::Server.start(app: dispatch,
                       server: server,
                       Host: host,
                       Port: port,
                       signals: false)
  end
end

class HelloApp < Sinatra::Base
  configure do
    set :threaded, false
  end

  get '/' do
    erb :index, layout: :layout
  end

  get '/stream' do
    request.websocket do |ws|
      ws.onopen do
        puts 'opened ws'
        $sockets << ws
      end

      ws.onmessage do |msg|
        EM.next_tick { $sockets.each { |s| s.send(msg) } }
      end
      ws.onclose do
        $sockets.delete(ws)
      end
    end
  end
end

run app: HelloApp.new
