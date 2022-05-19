# frozen_string_literal: true

module MultiprocessingPool
  ##
  # class to represent the process doing the actual work.
  class Process

    def initialize(receive_queue, future_queue)
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
      @receive_queue = receive_queue
      @future_queue = future_queue
    end

    ##
    # fork the child process and start its busy loop
    # to wait for instructions
    def start
      @pid = ::Process.fork do 
        child = ChildProcess.new(@receive_queue, @future_queue)
        child.start
      end
    end
   
    ##
    # instruct the child process to exit with a USR1 signal.
    # wait for it to avoid any zombie processes
    def join 
      ::Process.kill("USR1", @pid)
      ::Process.wait(@pid)
    end

  end

  ##
  # actual child that does the processing
  class ChildProcess 
    def initialize(receive_queue, future_queue)
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
      
      @receive_queue = receive_queue
      @future_queue = future_queue

      @obj_cache = {}

      Signal.trap("USR1") do
        shutdown
      end
    end

    ##
    # busy loop for child.  wait for instructions 
    # from parent, process task, and then return 
    # the results to the parent
    def start 

      loop do 

        task = get_task
        next if task.nil?  
        result = process task
        put_result(task, result)

      end

    end

    ##
    # actually process the task.  check the object
    # cache for the worker to see if we have already 
    # created a task with this class.  If not, create 
    # a new worker task and call the work method 
    # with the arguments of the task.  If the arguments
    # are passed as an array, then call the task as a splat.
    def process(task)
      clazz = Kernel.const_get(task["class_name"])

      if @obj_cache[clazz].nil? 
        @obj_cache[clazz] = clazz.new
      end

      obj = @obj_cache[clazz]

      method = task["method_name"].to_sym
      args = task["args"]
      if args.kind_of?(Array)
        obj.send(method, *args)
      else
        obj.send(method, args)
      end
    end

    ##
    # receive work instructions from the parent
    def get_task
      payload = nil
      @receive_queue.lock do 
        len = WireProtocol.decode_length(@receive_queue.socket_r.read(2))
        payload = WireProtocol.decode_message(@receive_queue.socket_r.read(len))
      end
      if payload.nil?
        @log.warn "Warning child received null payload.  Did the parent die and close the socket?"
        shutdown
      end

      data = JSON.parse(payload)
      @log.debug "received #{data}"
      data
    end

    ##
    # send work results back to the parent
    def put_result(task, result)
      payload = { :id => task["id"], :result => result }.to_json
      @future_queue.lock do 
        msg = WireProtocol.encode_message(payload)
        len = WireProtocol.encode_length(msg)
        @future_queue.socket_w.write(len)
        @future_queue.socket_w.write(msg)
      end
    end

    ##
    # shutdown the worker
    def shutdown 
      exit
    end

  end

end