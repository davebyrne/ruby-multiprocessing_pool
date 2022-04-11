# frozen_string_literal: true

module MultiprocessingPool
  class Future

    def initialize(id)
      @id = id
      @mutex = Mutex.new
      @cond = ConditionVariable.new
      @ready = false
    end

    attr_reader :id

    def get
      @mutex.synchronize do 
        unless is_ready?
          @cond.wait(@mutex)
        end
        return @value
      end
    end

    def set(value)
      @mutex.synchronize do 
        @value = value
        @ready = true
        @cond.signal
      end
    end

    def is_ready?
      @ready
    end

  end
end