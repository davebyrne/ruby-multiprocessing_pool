# frozen_string_literal: true

RSpec.describe MultiprocessingPool do
  it "has a version number" do
    expect(MultiprocessingPool::VERSION).not_to be nil
  end

  it "creates a pool and manages the lifecycle" do 
    mock_pool = double(:pool)
    allow(MultiprocessingPool::ProcessPoolManager).to receive(:new).and_return(mock_pool)
    expect(mock_pool).to receive(:start)
    expect(mock_pool).to receive(:join)
    MultiprocessingPool::ProcessPool(workers: 10) do |pool|
      expect(pool).to eq(mock_pool)
    end
  end

  
  it "does the work in the pool given a method" do 

    class Bar
      def triple(num)
        num * 3
      end
    end

    MultiprocessingPool::ProcessPool(workers: 2) do |pool|
      results = pool.map(Bar, :triple, ([1,2,3]))
      expect(results).to eq([3,6,9])
    end
    
  end

  # it "does fibinacci to benchmark" do 
  #   class Fibonacci 
  #     def fibonacci( n )
  #       return  n  if n <= 1 
  #       fibonacci( n - 1 ) + fibonacci( n - 2 )
  #     end 
  #   end

  #   MultiprocessingPool::ProcessPool(workers: 2) do |pool|
  #     results = pool.map(Fibonacci, :fibonacci, (30..40).to_a)
  #     expect(results).to eq([3,6,9])
  #   end

  # end

end
