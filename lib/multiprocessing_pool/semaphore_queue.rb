# frozen_string_literal: true

require 'sys_stuff'

module MultiprocessingPool
  class SemaphoreQueue

    # an IO Pipe that is protected by a semaphore lock.  This allows
    # multiple processes to wait on the pipe for instructions without
    # any of them interferring with each other.
    def initialize 
      id = (rand() * 1000).to_i
      @semaphore = SysStuff::Posix::NamedSemaphore.create("queue_#{id}", 1)
      @semaphore.unlink!

      @pipe_r, @pipe_w = IO.pipe
    end

    def lock(&block) 
      @semaphore.wait
      block.call
      @semaphore.post
    end

    def socket_r
      @pipe_r
    end

    def socket_w
      @pipe_w
    end

    def close
      @semaphore.close
    end

  end
end