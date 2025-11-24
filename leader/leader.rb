require 'sinatra'
require 'sinatra/cross_origin'
require 'json'
require 'http'
require 'dotenv'
require_relative './lib/store'

if ARGV.length < 1
  abort "usage: bundler exec ruby leader.rb PORT"
end

port = ARGV[0].to_i
abort 'invalid port' if port < 0

set :port, port
set :bind, '0.0.0.0'

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, PUT, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With'
  if request.content_type == 'application/json'
    body = request.body.read
    @json_params = JSON.parse(body) unless body.empty?
  end
end

Dotenv.load
STORE = Store.new
FOLLOWERS = ENV['FOLLOWERS'].split(',')
QUORUM = ENV['WRITE_QUORUM'].to_i
MIN_DELAY = ENV['MIN_DELAY'].to_i
MAX_DELAY = ENV['MAX_DELAY'].to_i

get '/' do
  'leader is up'
end

options '*' do
  response.headers['Allow'] = 'GET, PUT, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With'
  200
end

# GET /read
get '/read' do
  result = STORE.read

  if result.is_a?(Exception)
    status 409
    content_type :json
    { status: "cannot read store: #{result.message}", store: nil }.to_json
  else
    content_type :json
    status 200
    { status: 'success', store: result }.to_json
  end
end

# PUT /write
put '/write' do
  key = @json_params['key']
  value = @json_params['value']

  result = STORE.write(key, value)

  successes = 0
  mutex = Mutex.new
  cv = ConditionVariable.new

  FOLLOWERS.each do |follower_url|
    Thread.new do
      sleep(rand(MIN_DELAY..MAX_DELAY) / 1000.0)

      begin
        puts "sending replicate request to #{follower_url}/replicate"

        response = HTTP.put("#{follower_url}/replicate",
                            json: { key: key, value: value })

        if response.code == 200
          mutex.synchronize do
            successes += 1
            cv.signal if successes >= QUORUM
          end
        end
      rescue => e
        puts "replication failed: #{e.message}"
      end
    end
  end

  mutex.synchronize do
    cv.wait(mutex) until successes >= QUORUM
  end

  if result.is_a?(Exception)
    status 409
    content_type :json
    {
      status: "cannot write to store: #{result.message}",
      received_key: key,
      received_value: value
    }.to_json
  else
    content_type :json
    status 200
    {
      status: 'success',
      received_key: key,
      received_value: value
    }.to_json
  end
end

puts "leader listening at http://localhost:#{port}"