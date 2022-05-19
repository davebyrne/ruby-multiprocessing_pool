# frozen_string_literal: true

module MultiprocessingPool
  ##
  # Creates a pool of processes and manages their lifecycle. 
  # This is is public interface for submiting work to the pool.
  class ProcessPoolManager
    def initialize(opts)
      unless !opts[:workers].nil? && opts[:workers].is_a?(Integer)
        raise MultiprocessingPool::Error.new("number of workers missing")
      end

      @workers = opts[:workers]

      @processes = []
      @task_manager = TaskManager.new
    end

    ##
    # start the pool of workers and the task manager 
    # for submiting and receiving results from the pool
    def start
      (1..@workers).each do 
        p = @task_manager.create_process
        @processes << p
        p.start
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