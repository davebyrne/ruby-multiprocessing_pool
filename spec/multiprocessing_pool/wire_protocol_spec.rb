# frozen_string_literal: true

RSpec.describe MultiprocessingPool::WireProtocol do
  it "encodes and decodes to the same values" do 
    message = "the quick brown fox\njumps\nover the lazy dog"
    
    encoded = MultiprocessingPool::WireProtocol.encode_message(message)
    encoded_len = MultiprocessingPool::WireProtocol.encode_length(encoded)

    decoded_len = MultiprocessingPool::WireProtocol.decode_length(encoded_len)
    decoded = MultiprocessingPool::WireProtocol.decode_message(encoded)

    expect(decoded).to eq(message)
    expect(decoded_len).to eq(encoded.bytesize)    
  end
end
