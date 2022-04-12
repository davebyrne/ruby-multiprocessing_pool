# frozen_string_literal: true

module MultiprocessingPool
  class Process

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

    def submit(future, clazz, method, args)
      payload = { 
        :id => future.id,
        :class_name => clazz,
        :method_name => method,
        :args => args
      }.to_json
      puts "Writing #{payload}"
      msg = [payload].pack("Z*")
      len = [msg.length].pack("S")
      @parent_w.write(len)
      @parent_w.write(msg)
    end

    def socket 
      @parent_r
    end

    def join 
      ::Process.kill("USR1", @pid)
      ::Process.wait(@pid)
    end

  end

  class ChildProcess 
    def initialize(socket_r, socket_w)
      @socket_r = socket_r
      @socket_w = socket_w

      @obj_cache = {}

      Signal.trap("USR1") do
        shutdown
      end
    end

    def start 

      loop do 

        task = get_task
        next if task.nil?  
        result = process task
        put_result(task, result)

      end

    end

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

    def get_task
      len = @socket_r.read(2).unpack("S").first
      payload = @socket_r.read(len).unpack("Z*").first
      if payload.nil?
        puts "Warning child received null payload.  Did the parent die and close the socket?"
        shutdown
      end

      data = JSON.parse(payload)
      puts "received #{data}"
      data
    end

    def put_result(task, result)
      payload = { :id => task["id"], :result => result }.to_json
      msg = [payload].pack("Z*")
      len = [msg.length].pack("S")
      @socket_w.write(len)
      @socket_w.write(msg)
    end

    def shutdown 
      exit
    end

  end

end