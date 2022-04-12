# frozen_string_literal: true

require 'json' 
require 'securerandom'

module MultiprocessingPool
  class ProcessPoolManager
    def initialize(opts)
      unless !opts[:workers].nil? && opts[:workers].is_a?(Integer)
        raise MultiprocessingPool::Error.new("number of workers missing")
      end

      @workers = opts[:workers]

      @processes = CircularQueue.new
      @task_manager = TaskManager.new
    end

    def map(clazz, method, args) 
      args.map { |arg| submit(clazz, method, arg) } 
        .map { |future| future.get }
    end

    def start
      (1..@workers).each do 
        p = Process.new
        @processes << p
        p.start
        @task_manager.add_reader(p.socket)
      end

      @task_manager.start
    end

    def apply_async(clazz, method, args)
      submit(clazz, method, args)
    end

    def join 
      @task_manager.join
      @processes.each { |p| p.join }
    end

    private 
    def submit(clazz, method, arg)

      future = Future.new(SecureRandom.uuid)
      @task_manager.add_future future
      @processes.next.submit(future, clazz, method, arg)
      
      future
    end

  end

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

  class TaskManager

    def initialize
      @readers = []
      @mutex = Mutex.new
      @futures = {}
    end

    def add_reader(socket)
      @readers << socket
    end

    def start

      @reader_thread = Thread.new do 
        monitor_reads
      end

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
              puts "removing socket from dead process"
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
        puts "partial length"
        IO.select([sock])
        retry 
      end
      
      begin 
        payload = WireProtocol.decode_message(sock.read_nonblock(len))
        return payload
      rescue IO::WaitReadable
        puts "partial message"
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
      puts "parent got #{payload}"
      data = JSON.parse(payload)
      @mutex.synchronize do 
      
        unless @futures.has_key? data["id"]
          puts "Unexpected future id #{data['id']}. this should not happen."
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