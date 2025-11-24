class Store
  attr_accessor :store

  def initialize
    @store = {}
  end

  def read
    @store
  end

  def write(key, value)
    if @store.include?(key)
      # log update
      @store[key] = value
    else
      # log write
      @store[key] = value
    end
  end
end