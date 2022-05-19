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
      @mutex = Mutex.new
      @futures = {}
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
      @submit_queue = SemaphoreQueue.new
      @future_queue = SemaphoreQueue.new
    end

    def create_process
      Process.new(@submit_queue, @future_queue)
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
    def submit(clazz, method, args)
      future = Future.new(SecureRandom.uuid)
      add_future future

      payload = { 
        :id => future.id,
        :class_name => clazz,
        :method_name => method,
        :args => args
      }.to_json

      @log.debug "Writing #{payload}"
      msg = WireProtocol.encode_message(payload)
      len = WireProtocol.encode_length(msg)
      @submit_queue.socket_w.write(len)
      @submit_queue.socket_w.write(msg)
      
      future
    end

    ##
    # wait for any child to send task results.  
    # update the future with the results when they are received
    #
    def monitor_reads

      sock = @future_queue.socket_r

      loop do 

        len = WireProtocol.decode_length(sock.read(2))
        future = WireProtocol.decode_message(sock.read(len))
        update_future future unless future.nil?
        
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
      @future_queue.close
      @submit_queue.close
    end

  end
end