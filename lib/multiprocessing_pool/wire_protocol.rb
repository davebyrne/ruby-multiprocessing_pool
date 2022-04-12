# frozen_string_literal: true

module MultiprocessingPool

  ##
  # class describing the wire protocol.
  # messages are sent with a 2 byte integer specifying length
  # followed by the actual message as a null terminated string
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

