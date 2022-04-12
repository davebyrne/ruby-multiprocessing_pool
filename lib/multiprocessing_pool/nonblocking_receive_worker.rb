# frozen_string_literal: true

module MultiprocessingPool
  class NonblockingRecieveWorker

    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::WARN
    end

    ##
    # using non-blocking IO, wait for any child to send
    # task results.  update the future with the results
    # when they are received
    def start(processes, &block) 

      readers = processes.map {|x| x.socket }

      loop do 
        ready_sockets = IO.select(readers, [], [])
      
        read = ready_sockets[0]
          read.each do |sock|
            begin 
              future = read_socket(sock)
              unless future.nil?
                @log.debug "parent got #{future}"
                yield JSON.parse(future)
              end
            rescue EOFError 
              @log.warn "removing socket from dead process"
              readers.delete(sock)
            end
          end
        
      end
    end

    ##
    # read the socket from the child with the results.
    def read_socket(sock) 
      
      # fake a blocking socket when trying to read a full 
      # message.  this prevents having to buffer the response.
      # if the socket is readable, then it should shortly have 
      # the entire response if it doesnt already

      begin     
        len = WireProtocol.decode_length(sock.read_nonblock(2))
      rescue IO::WaitReadable
        IO.select([sock])
        retry 
      end
      
      begin 
        return WireProtocol.decode_message(sock.read_nonblock(len))
      rescue IO::WaitReadable
        IO.select([sock])
        retry
      end
    end
    
  end
end