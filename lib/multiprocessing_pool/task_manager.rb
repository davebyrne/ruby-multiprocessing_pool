# frozen_string_literal: true
require 'logger'
require 'json'
require 'securerandom'

module MultiprocessingPool

  ##
  # class to manage the work tasks in-flight and 
  # to submit new tasks to the pool.  this class
  # starts a new thread that watches all of the 
  # child pipes for results using non-blocking IO.  
  # When results are received, the future is updated
  # to notify the caller that results are ready.
  #
  # new submissions of work are handled in a round-robin
  # fashion to all of the children, without regard to which 
  # children are busy or free.
  class TaskManager

    def initialize
      @readers = []
      @mutex = Mutex.new
      @futures = {}
      @processes = CircularQueue.new
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
    end

    def add_process(process)
      @readers << process.socket
      @processes << process
    end

    ##
    # start the thread that monitors the children for results.
    # this method should not be called before all children have 
    # been started to avoid them from forking the monitor thread.
    def start

      @reader_thread = Thread.new do 
        monitor_reads
      end

    end

    ##
    # submit a new task to the pool and add the future 
    # to the monitoring pool
    def submit(clazz, method, arg)
      future = Future.new(SecureRandom.uuid)
      add_future future
      @processes.next.submit(future, clazz, method, arg)
      
      future
    end

    ##
    # using non-blocking IO, wait for any child to send
    # task results.  update the future with the results
    # when they are received
    def monitor_reads

      loop do 
        ready_sockets = IO.select(@readers, [], [])
      
        read = ready_sockets[0]
          read.each do |sock|
            begin 
              future = read_socket(sock)
              update_future future unless future.nil?
            rescue EOFError 
              @log.warn "removing socket from dead process"
              @readers.delete(sock)
            end
          end
        
      end
    end

    ##
    # read the socket from the child with the results.
    def read_socket(sock) 
      
      # fake a blocking socket when trying to read a full 
      # message.  this prevents having to buffer the response.
      # if the socket is readable, then it should shortly have 
      # the entire response if it doesnt already

      begin     
        len = WireProtocol.decode_length(sock.read_nonblock(2))
      rescue IO::WaitReadable
        IO.select([sock])
        retry 
      end
      
      begin 
        return WireProtocol.decode_message(sock.read_nonblock(len))
      rescue IO::WaitReadable
        IO.select([sock])
        retry
      end
    end

    ##
    # add a pending future to the in-flight tracking list
    def add_future(future)
      @mutex.synchronize do 
        @futures[future.id] = future
      end
    end

    ##
    # mark an in-flight request as complete and remove it 
    # from the tracking list
    def update_future(payload)
      @log.debug "parent got #{payload}"
      data = JSON.parse(payload)
      @mutex.synchronize do 
      
        unless @futures.has_key? data["id"]
          @log.warn "Unexpected future id #{data['id']}. this should not happen."
          return
        end

        future = @futures[data["id"]]
        future.set data["result"]
        @futures.delete(data["id"])
      end
    end

    ##
    # stop the results monitoring thread
    def join 
      @reader_thread.kill
      @reader_thread.join
    end

  end
end