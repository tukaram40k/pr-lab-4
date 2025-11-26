require 'net/http'
require 'json'
require 'time'

ports = (4568..4572).to_a
stores = []

ports.each do |port|
  uri = URI("http://localhost:#{port}/read")
  data = JSON.parse(Net::HTTP.get(uri))
  stores << { port: port, store: data["store"] }
end

normalized = stores.map { |s| { port: s[:port], store: s[:store].transform_values(&:to_s) } }

base = normalized.first[:store]
mismatches = []

normalized[1..].each do |entry|
  diff = {}
  all_keys = (base.keys + entry[:store].keys).uniq

  all_keys.each do |k|
    base_val = base[k]
    other_val = entry[:store][k]
    diff[k] = { base: base_val, other: other_val } if base_val != other_val
  end

  mismatches << { port: entry[:port], diff: diff } unless diff.empty?
end

if mismatches.empty?
  puts true
else
  puts false

  timestamp = Time.now.utc.iso8601.gsub(":", "-")
  filename = "simulation/diff_#{timestamp}.txt"

  File.open(filename, "w") do |f|
    mismatches.each do |m|
      f.puts "Port #{m[:port]} differences:"
      m[:diff].each do |k, v|
        f.puts "  Key #{k}: base=#{v[:base]}, other=#{v[:other]}"
      end
      f.puts
    end
  end
end
