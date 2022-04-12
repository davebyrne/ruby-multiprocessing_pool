# frozen_string_literal: true

module MultiprocessingPool
  ##
  # class to represent the ractor doing the actual work.
  class Ractor

    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
    end

    ##
    # create a worker ractor and start its busy loop
    # to wait for instructions
    def start
     @ractor = ::Ractor.new do 
        child = ChildRactor.new
        child.start
      end
    end

    ## 
    # submit a task to the worker ractor via its send channel
    def submit(future, clazz, method, args)
      payload = { 
        "id" => future.id,
        "class_name" => clazz,
        "method_name" => method,
        "args" => args
      }
      @ractor.send(payload)
    end

    ##
    # just return the ractor here since the receive worker
    # will select on it
    def socket 
      @ractor
    end

    ##
    # instruct the child ractor to exit with a command
    def join 
      @ractor.send({"command" => "stop"})
    end

  end

  ##
  # actual child that does the processing
  class ChildRactor 
    def initialize
      @log = Logger.new($stdout)
      @log.level = Logger::WARN
      
      @obj_cache = {}
    end

    ##
    # busy loop for child.  wait for instructions 
    # from parent, process task, and then return 
    # the results to the parent
    def start 

      loop do 

        task = get_task
        next if task.nil?  
        break if task["command"] == "stop"

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

      clazz = task["class_name"]

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
    # receive work instructions from the main ractor
    def get_task
      data = ::Ractor.receive
      @log.debug "received #{data}"
      data
    end

    ##
    # send work results back to the main rator
    def put_result(task, result)
      payload = { "id" => task["id"], "result" => result }
      ::Ractor.yield payload
    end

  end

end