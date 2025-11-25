require "net/http"
require "json"

URL = "http://localhost:4567/write"

THREADS = 10
REQS_PER_THREAD = 10

latencies = []
mutex = Mutex.new

threads = (1..THREADS).map do |i|
  Thread.new do
    REQS_PER_THREAD.times do
      key = i.to_s
      value = rand(1..100).to_s

      uri = URI(URL)
      req = Net::HTTP::Put.new(uri, "Content-Type" => "application/json")
      req.body = { key: key, value: value }.to_json

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
      finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      latency = (finish - start) * 1000.0

      mutex.synchronize { latencies << latency }

      unless res.is_a?(Net::HTTPSuccess)
        warn "request failed: #{res.code} #{res.body}"
      end
    end
  end
end

threads.each(&:join)

avg = latencies.sum / latencies.size
puts avg
