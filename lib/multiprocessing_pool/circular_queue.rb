# frozen_string_literal: true

module MultiprocessingPool
  class CircularQueue
    include Enumerable

    def initialize 
      @idx = 0
      @arr = []
    end

    def each 
      @arr.each { |i| yield i }
    end

    def next 

      obj = @arr[@idx]

      @idx += 1
      if @idx >= @arr.length
        @idx = 0
      end

      return obj
    end

    def <<(obj)
      @arr << obj
    end

    def to_a 
      return @arr
    end

  end
end