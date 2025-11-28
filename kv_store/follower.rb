require 'sinatra'
require 'sinatra/cross_origin'
require 'json'
require 'dotenv'
require_relative './lib/store'
require_relative './lib/request_controller'

if ARGV.length < 1
  abort "usage: bundler exec ruby follower.rb PORT"
end

port = ARGV[0].to_i
abort 'invalid port' if port < 0

set :port, port
set :bind, '0.0.0.0'
set :environment, :production

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, PUT, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With'
  if request.media_type == 'application/json'
    body = request.body.read
    @json_params = JSON.parse(body) unless body.empty?
  end
end

Dotenv.load
STORE = Store.new

get '/' do
  'follower is up'
end

options '*' do
  response.headers['Allow'] = 'GET, PUT, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With'
  200
end

# GET /read
get '/read' do
  response = RequestController.process_read
  status response[:status]
  content_type :json
  response[:body].to_json
end

# PUT /replicate
put '/replicate' do
  key = @json_params['key']
  value = @json_params['value']
  version = @json_params['version']

  response = RequestController.process_replicate(key, value, version)
  status response[:status]
  content_type :json
  response[:body].to_json
end

puts "follower listening at http://localhost:#{port}"