# frozen_string_literal: true

module MultiprocessingPool
  class RactorRecieveWorker

    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
    end

    ##
    # take a list of ractors and wait for a result
    # to become available on the receive channel.
    def start(workers, &block) 

      readers = workers.map {|x| x.socket }

      loop do 
        r, future = ::Ractor.select(*readers)
        yield future
      end
    end    
  end
end