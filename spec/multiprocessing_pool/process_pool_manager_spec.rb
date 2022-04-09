# frozen_string_literal: true

RSpec.describe MultiprocessingPool::ProcessPoolManager do
  it "raises an error if the size of the pool is not passed" do 
    expect { MultiprocessingPool::ProcessPoolManager.new({}) }.to(
      raise_error(MultiprocessingPool::Error, /number of workers missing/))
  end
end
