# frozen_string_literal: true

RSpec.describe MultiprocessingPool::CircularQueue do
  it "it circles through the objects in the queue" do 
    queue = MultiprocessingPool::CircularQueue.new
    queue << "a"
    queue << "b"
    queue << "c"
    expect(queue.next).to eq("a")
    expect(queue.next).to eq("b")
    expect(queue.next).to eq("c")
    expect(queue.next).to eq("a")
  end
end
