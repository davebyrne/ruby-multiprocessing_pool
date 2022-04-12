# MultiprocessingPool

A process-based parallisim library for Ruby inspired by Python's [multiprocessing.Pool](https://docs.python.org/3/library/multiprocessing.html). MRI Ruby has a Global Interpretor Lock which prevents multiple threads from concurrently running.  This gem will spawn a group of independant worker processes which will effectively side-step the Global Interpretor Lock and allow true parallelism while hiding the complexity of multi-process IPC.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'multiprocessing_pool',  git: 'https://github.com/davebyrne/ruby-multiprocessing-pool'
```

And then execute:

    $ bundle install


Note: *this gem has not been published to rubygems. It is only maintained on an as-needed-basis.*

## Usage

To calculate a fibonacci sequence in parallel:
```ruby
require 'multiprocessing_pool'

# create a class that represents the work to do
class Fibonacci
    def calc(n)
        return  n  if n <= 1 
        calc( n - 1 ) + calc( n - 2 )
    end
end

# create a pool of workers
MultiprocessingPool::ProcessPool(workers: 2) do |pool|

    # submit a list of tasks to the pool and wait 
    # for the results
    results = pool.map(Fibonacci, :calc, (1..5).to_a)
    
    # will return [1,1,2,3,5]
    puts results

end
```

Tasks can also be submitted independently:
```ruby
require 'multiprocessing_pool'

class Fibonacci
    def calc(n)
        return  n  if n <= 1 
        calc( n - 1 ) + calc( n - 2 )
    end
end

MultiprocessingPool::ProcessPool(workers: 2) do |pool|

    # submit tasks and get a future result
    future = pool.apply_async(Fibonacci, :calc, 5)
    
    # will block until the task is complete.
    puts future.get 

end
```

Methods with multiple args can be passed as arrays: 
```ruby
require 'multiprocessing_pool'

# class that has multiple arguments
class Sum
    def calc(a, b)
        a + b
    end
end

MultiprocessingPool::ProcessPool(workers: 2) do |pool|

    # submit a list of tasks to the pool and wait 
    # for the results
    results = pool.map(Fibonacci, :calc, [
        [1,1],
        [2,2]
    ])
    
    # will return [2, 4]
    puts results

end
```

## Differences from Python

There are two major differences between this implementation and the implementation found in the Python standard library.  

First, Python will serialize the work method over the network.  This implementation passes the name of the class/method which is then instantiated on the worker process.  This means that your work class does not need to be serializable.

Second, Python uses a shared socket that is protected by a named semaphore to communicate with the workers.  This means as soon as a worker is done with a task, it can immediately try and aquire the lock and receive the next task.  AFAIK Ruby does not have an implementation of named semaphores (or other multi-process ipc lock).  Instead, this implementation creates a pipe per worker and work is distributed in a round-robin fashion.  This is slightly less efficient for cases where workers are finishing tasks at different rates, although it is somewhat offset by the operating system buffering of the receive pipes.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/davebyrne/ruby-multiprocessing_pool.
