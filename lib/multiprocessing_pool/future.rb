# frozen_string_literal: true

module MultiprocessingPool
  ##
  # class representing a future result.  callers can block on 
  # this class waiting for the results from their processing
  class Future

    def initialize(id)
      @id = id
      @mutex = Mutex.new
      @cond = ConditionVariable.new
      @ready = false
    end

    attr_reader :id

    ##
    # get the result of the task.  if the result is not 
    # yet available, then block and wait
    def get
      @mutex.synchronize do 
        unless is_ready?
          @cond.wait(@mutex)
        end
        return @value
      end
    end

    ## 
    # set the result of the task. notify any threads waiting
    # that the result is available
    def set(value)
      @mutex.synchronize do 
        @value = value
        @ready = true
        @cond.signal
      end
    end

    ##
    # is the task completed?
    def is_ready?
      @ready
    end

  end
end