require "multiprocessing_pool"

pool = MultiprocessingPool.new(:workers => 10)

results = pool.map(:fib, [2,3,5])



MultiprocessingPool.new(:workers => 10) do |pool|
  results = pool.map([2,3,5]) do |work|
    return self.fib(work)
  end
end