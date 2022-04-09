module MultiprocessingPool
  class ProcessPoolManager
    def initialize(opts)
      unless !opts[:workers].nil? && opts[:workers].is_a?(Integer)
        raise MultiprocessingPool::Error.new("number of workers missing")
      end

      @workers = opts[:workers]
    end

    def map(method, args) 
      # blocking method that waits until all results are available
      args.map { |arg| next_process_submit(method, args) }
        .map { |future| future.get }
    end

    def start
      (1..@workers).each do 
        child_main
      end
    end

    def join 
      # wait on process list
      # if a child ends with a non-zero exit status 
      # then raise an error and kill remaining processes
    end

    def child_main
      # create pipe pair and fork
      # children listen on pipe pair
    end

    def next_process
      # get the next process in a round robin fashion?
    end
    

    # split these into a TaskManager class
    # on #start add the pipe to task_manager
    # on submit give the future a reference 
    # and then block on get.
    # a TaskManager is better than a Process class
    # because all of the sockets can bet IO.selected
    # instead of blocking on a single socket?.... maybe
    # this is not useful because the calling thread will
    # block regardless and we are not waiting for the "first"
    # result
    def next_process_submit
      # store the future in a pending tasks hashmap
      # future will have a reference to this object
      # so it can block on first call to get
    end

    # a future will have a reference to this?
    # if the future is not ready, then block on 
    # the receive pipe until that result is ready
    def block_for_result(uuid)

    end

    def wait_for_next_result

    end

  end
end

# idea1: 
# create a process class.  Start will fork the process with a socket pair
# submit will add a task to the child and keep a future in the pending hashmap
# future will have a reference to the process which will have a .get(future) method
# that method will block on the socket and if any other futures are satisified from the
# socket first, then it will remove them from the pending hashmap and notify

# idea2:
# we can't just shove a gig of data on socket write without it blocking for a reciever read
# so we have to have a queuing interface anyways.  1 task per child by the fact we have a process
# so create a queue for "submit".  submit writes from parent to child.  child has a return queue.
# on recieve, child process and then writes.  this works for map but not apply_async.  
# how does python do it?

# apply async assumes that we can write to the child process anytime we want (via some sort of queuing mechanizim)
# and get futures.  it also assumes that the child will process and write back to the parent as it
# needs to and will not block on returning a result.


# python has 4 threads per process.  worker_handler task_handler and result_handler

# what about using non-blocking sockets?  parent writes to pipe. on EWOULDBLOCK, continue loop and 
# check child read socket.  continue event loop until parent completes a write.
# for child.  read from pipe, this should be blocking because we have nothing to do.  process data
# and write to parent.  this should also be blocking because we have nothing else to do.  non-blocking
# sockets should let apply_async work for parent without creating threads.  non-blocking sockets 
# could be troublesome because there is no guarantee that when data is available it is the entire message
# (as opposed to #read() returns half the data, and then EWOULDBLOCK?)  this is because nonblocking sockets
# require reading a fix number of bytes (as opposed to until there is a newline char)