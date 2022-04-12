# frozen_string_literal: true

module MultiprocessingPool
  ##
  # class to represent the process doing the actual work.
  # A pipe pair is created and a child process is forked.
  # communication to the child is sent over this channel.
  class Process

    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
    end

    ##
    # fork the child process and start its busy loop
    # to wait for instructions
    def start
      @parent_r, @child_w = IO.pipe
      @child_r, @parent_w = IO.pipe
      @pid = ::Process.fork do 
        @parent_r.close
        @parent_w.close
        child = ChildProcess.new(@child_r, @child_w)
        child.start
      end
      @child_r.close
      @child_w.close
    end

    ## 
    # submit a task to the worker process over
    # the open pipe.
    def submit(future, clazz, method, args)
      payload = { 
        :id => future.id,
        :class_name => clazz,
        :method_name => method,
        :args => args
      }.to_json
      @log.debug "Writing #{payload}"
      msg = WireProtocol.encode_message(payload)
      len = WireProtocol.encode_length(msg)
      @parent_w.write(len)
      @parent_w.write(msg)
    end

    ##
    # the read-end of the pipe from the child.
    # this is for receiving the results of a 
    # work task
    def socket 
      @parent_r
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
    def initialize(socket_r, socket_w)
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
      
      @socket_r = socket_r
      @socket_w = socket_w

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
      len = WireProtocol.decode_length(@socket_r.read(2))
      payload = WireProtocol.decode_message(@socket_r.read(len))
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
      msg = WireProtocol.encode_message(payload)
      len = WireProtocol.encode_length(msg)
      @socket_w.write(len)
      @socket_w.write(msg)
    end

    ##
    # shutdown the worker
    def shutdown 
      exit
    end

  end

end