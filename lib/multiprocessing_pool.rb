# frozen_string_literal: true

require_relative "multiprocessing_pool/version"
require_relative "multiprocessing_pool/future"
require_relative "multiprocessing_pool/process_pool_manager"
require_relative "multiprocessing_pool/process"


module MultiprocessingPool
  class Error < StandardError; end
  
  def self.ProcessPool(opts, &block)
    pool = ProcessPoolManager.new(opts)
    pool.start
    block.call pool
    pool.join
  end
end
