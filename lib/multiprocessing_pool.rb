# frozen_string_literal: true

require_relative "multiprocessing_pool/version"
require_relative "multiprocessing_pool/wire_protocol"
require_relative "multiprocessing_pool/future"
require_relative "multiprocessing_pool/circular_queue"
require_relative "multiprocessing_pool/task_manager"
require_relative "multiprocessing_pool/pool_manager"
require_relative "multiprocessing_pool/process"
require_relative "multiprocessing_pool/nonblocking_receive_worker"


module MultiprocessingPool
  class Error < StandardError; end
  
  def self.ProcessPool(opts, &block)
    std_opts = {
      :worker_type => MultiprocessingPool::Process,
      :receive_worker => NonblockingRecieveWorker.new
    }
    pool = PoolManager.new(opts.merge(std_opts))
    begin 
      pool.start
      block.call pool
    ensure 
      pool.join
    end
  end
end
