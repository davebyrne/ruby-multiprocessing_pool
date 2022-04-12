# frozen_string_literal: true

module MultiprocessingPool
  class WireProtocol

    def self.encode_length(message)
      [message.bytesize].pack("S")      
    end

    def self.encode_message(message)
      [message].pack("Z*")
    end

    def self.decode_message(message)
      message.unpack("Z*").first
    end

    def self.decode_length(length)
      length.unpack("S").first
    end
  end
end

