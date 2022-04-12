# frozen_string_literal: true

RSpec.describe MultiprocessingPool::PoolManager do
  it "raises an error if the size of the pool is not passed" do 
    expect { MultiprocessingPool::PoolManager.new({}) }.to(
      raise_error(MultiprocessingPool::Error, /number of workers missing/))
  end

  it "raises an error if the worker type is not passed" do 
    expect { MultiprocessingPool::PoolManager.new({:workers => 2}) }.to(
      raise_error(MultiprocessingPool::Error, /worker type is missing/))
  end

  it "raises an error if the recieve worker is not passed" do 
    expect { MultiprocessingPool::PoolManager.new({:workers => 2, :worker_type => MultiprocessingPool::Process}) }.to(
      raise_error(MultiprocessingPool::Error, /missing recieve worker/))
  end
end
