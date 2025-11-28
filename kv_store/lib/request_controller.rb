require 'http'

class RequestController
  # read (leader/follower)
  def self.process_read
    result = ::STORE.read

    if result.is_a?(Exception)
      { status: 409, body: { status: "cannot read store: #{result.message}", store: nil } }
    else
      { status: 200, body: { status: 'success', store: result } }
    end
  end

  # write and send replicas (leader)
  def self.process_write(key, value)
    version = ::STORE.next_version_for(key)
    result = ::STORE.write(key, value, version)

    successes = 0
    mutex = Mutex.new
    cv = ConditionVariable.new
    quorum_achieved = false
    timeout_reached = false

    ::FOLLOWERS.each do |follower_url|
      Thread.new do
        sleep(rand(::MIN_DELAY..::MAX_DELAY) / 1000.0)

        begin
          puts "sending replicate request to #{follower_url}/replicate"

          response = HTTP.put(
            "#{follower_url}/replicate",
            json: { key: key, value: value, version: version }
          )

          if response.code == 200
            mutex.synchronize do
              successes += 1
              cv.signal if successes >= ::QUORUM && !quorum_achieved
              quorum_achieved = true if successes >= ::QUORUM
            end
          end
        rescue => e
          puts "replication failed: #{e.message}"
        end
      end
    end

    mutex.synchronize do
      timeout_reached = !cv.wait(mutex, ::TIMEOUT / 1000)
    end

    if timeout_reached && successes < ::QUORUM
      return {
        status: 503,
        body: {
          status: "quorum not reached",
          received_key: key,
          received_value: value,
          successes: successes,
          quorum_required: ::QUORUM
        }
      }
    end

    if result.is_a?(Exception)
      {
        status: 409,
        body: {
          status: "cannot write to store: #{result.message}",
          received_key: key,
          received_value: value
        }
      }
    else
      {
        status: 200,
        body: {
          status: 'success',
          received_key: key,
          received_value: value,
          version: version
        }
      }
    end
  end

  # replicate (follower)
  def self.process_replicate(key, value, version)
    current = ::STORE.read_with_version(key)

    if current && current[:version] && version < current[:version]
      return {
        status: 200,
        body: {
          status: "ignored_old_write",
          received_key: key,
          received_value: value,
          received_version: version,
          current_version: current[:version]
        }
      }
    end

    result = ::STORE.write(key, value, version)

    if result.is_a?(Exception)
      {
        status: 409,
        body: {
          status: "cannot write to store: #{result.message}",
          received_key: key,
          received_value: value,
          received_version: version
        }
      }
    else
      {
        status: 200,
        body: {
          status: 'success',
          received_key: key,
          received_value: value,
          received_version: version
        }
      }
    end
  end
end