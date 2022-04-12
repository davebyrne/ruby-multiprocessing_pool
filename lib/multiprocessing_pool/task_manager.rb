# frozen_string_literal: true
require 'logger'

module MultiprocessingPool
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

    def start

      @reader_thread = Thread.new do 
        monitor_reads
      end

    end

    def submit(clazz, method, arg)
      future = Future.new(SecureRandom.uuid)
      add_future future
      @processes.next.submit(future, clazz, method, arg)
      
      future
    end

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

    def add_future(future)
      @mutex.synchronize do 
        @futures[future.id] = future
      end
    end

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


    def join 
      @reader_thread.kill
      @reader_thread.join
    end


  end
end