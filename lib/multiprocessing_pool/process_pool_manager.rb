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

      @processes = []
      @task_manager = TaskManager.new
    end

    def map(clazz, method, args) 
      args.map { |arg| @task_manager.submit(clazz, method, arg) } 
        .map { |future| future.get }
    end

    def start
      (1..@workers).each do 
        p = Process.new
        @processes << p
        p.start
        @task_manager.add_process p
      end

      @task_manager.start
    end

    def apply_async(clazz, method, args)
      @task_manager.submit(clazz, method, args)
    end

    def join 
      @task_manager.join
      @processes.each { |p| p.join }
    end

  end

end