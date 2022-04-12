# frozen_string_literal: true

require_relative "multiprocessing_pool/version"
require_relative "multiprocessing_pool/wire_protocol"
require_relative "multiprocessing_pool/future"
require_relative "multiprocessing_pool/process_pool_manager"
require_relative "multiprocessing_pool/process"


module MultiprocessingPool
  class Error < StandardError; end
  
  def self.ProcessPool(opts, &block)

    pool = ProcessPoolManager.new(opts)
    begin 
      pool.start
      block.call pool
    ensure 
      pool.join
    end
  end
end
