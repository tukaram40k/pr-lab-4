class Store
  def initialize
    @store = {}
    @mutex = Mutex.new
  end

  def read
    @mutex.synchronize { @store.dup }
  end

  def write(key, value)
    @mutex.synchronize do
      @store[key] = value
    end
  end
end
