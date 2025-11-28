class Store
  def initialize
    @store = {}
    @versions = {}
    @mutex = Mutex.new
  end

  def read
    @mutex.synchronize { @store.dup }
  end

  def write(key, value, ver)
    @mutex.synchronize do
      @store[key] = { value: value, version: ver }
    end
  end

  def next_version_for(key)
    @mutex.synchronize do
      @versions[key] = (@versions[key] || 0) + 1
    end
  end

  def read_with_version(key)
    @mutex.synchronize { @store[key] }
  end
end
