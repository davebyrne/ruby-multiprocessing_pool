# frozen_string_literal: true

module MultiprocessingPool
  ##
  # Creates a pool of workers and manages their lifecycle. 
  # This is is public interface for submiting work to the pool.
  class PoolManager
    def initialize(opts)
      unless !opts[:workers].nil? && opts[:workers].is_a?(Integer)
        raise MultiprocessingPool::Error.new("number of workers missing")
      end

      unless !opts[:worker_type].nil? && opts[:worker_type].is_a?(Class)
        raise MultiprocessingPool::Error.new("worker type is missing")
      end

      if opts[:receive_worker].nil?
        raise MultiprocessingPool::Error.new("missing recieve worker")
      end

      @workers = opts[:workers]
      @worker_clazz = opts[:worker_type]

      @processes = []
      @task_manager = TaskManager.new(opts[:receive_worker])
    end

    ##
    # start the pool of workers and the task manager 
    # for submiting and receiving results from the pool
    def start
      (1..@workers).each do 
        p = @worker_clazz.new
        @processes << p
        p.start
        @task_manager.add_process p
      end

      @task_manager.start
    end

    ##
    # given an array of work, send it to the pool for processing.
    # wait for all of the results to be received and return them to 
    # the caller
    def map(clazz, method, args) 
      args.map { |arg| @task_manager.submit(clazz, method, arg) } 
        .map { |future| future.get }
    end

    ##
    # given a single task, send it to the pool and return a 
    # future result for the caller to wait on for completion
    def apply_async(clazz, method, args)
      @task_manager.submit(clazz, method, args)
    end

    ##
    # stop the pool 
    def join 
      @task_manager.join
      @processes.each { |p| p.join }
    end

  end

end