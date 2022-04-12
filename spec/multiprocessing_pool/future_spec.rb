# frozen_string_literal: true

RSpec.describe MultiprocessingPool::Future do
  it "blocks until the value is available" do 
    future = MultiprocessingPool::Future.new("test")
    worker = Thread.new do 
      sleep(0.1)
      future.set(1)
    end
    expect(future.is_ready?).to be_falsey
    expect(future.get).to eq(1)
    expect(future.is_ready?).to be_truthy
    worker.join
  end

  it "access the value immediatly if its already there" do 
    future = MultiprocessingPool::Future.new("test")
    future.set(2)
    expect(future.is_ready?).to be_truthy
    expect(future.get).to eq(2)
  end
end
