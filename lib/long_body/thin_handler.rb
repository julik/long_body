# Turns an iterable Rack response body that responds to each() into
# something that Thin can use within EventMachine. Uses internal Thin
# interfaces so not applicable for other servers.
module LongBody::ThinHandler
  extend self
  
  AsyncResponse = [-1, {}, []].freeze

  # A wrapper that allows us to access an object that yields from each()
  # as if it were an Enumerator-ish object.
  #
  #   arr = %w( a b )
  #   w = FiberWrapper.new(arr)
  #   w.take #=> 'a'
  #   w.take #=> 'b'
  #   w.take #=> nil # Ended
  class FiberWrapper
    def initialize(eachable)
      @fiber = Fiber.new do
        eachable.each{|chunk| Fiber.yield(chunk.to_s) }
        eachable.close if eachable.respond_to?(:close)
        nil
      end
    end
    
    def take
      @fiber.resume
    rescue FiberError
      nil
    end
  end
  
  # Controls the scheduling of the trickle-feed using EM.next_tick.
  class ResponseSender
    attr_reader :deferrable_body
    def initialize(eachable_body)
      require_relative 'deferrable_body'
      require_relative 'lint_bypass'
      @eachable_body = eachable_body
      @enumerator = FiberWrapper.new(eachable_body)
      @deferrable_body = LongBody::DeferrableBody.new
    end
    
    def abort!
      @eachable_body.abort!
      @deferrable_body.fail
    end
    
    def send_next_chunk
      next_chunk = begin
        @enumerator.take
      rescue StandardError => e
        abort!
      end
      
      if next_chunk
        @deferrable_body.call([next_chunk]) # Has to be given in an Array
        EM.next_tick { send_next_chunk }
      else
        @deferrable_body.succeed
      end
    end
  end
  
  # We need a way to raise from each() when the connection
  # is closed prematurely.
  class BodyWrapperWithExplicitClose
    def abort!
      @aborted = true; close
    end
    
    def close
      @rack_body.close if @rack_body.respond_to?(:close)
    end
    
    def initialize(rack_body)
      @rack_body = rack_body
    end
    
    def each
      @rack_body.each do | bytes |
        # Break the body out of the loop if the response is aborted (client disconnect)
        raise "Disconnect or connection close" if @aborted
        yield(bytes)
      end
    end
  end
  
  C_async_close = 'async.close'.freeze
  C_async_callback = 'async.callback'.freeze
  
  def perform(env, s, h, b)
    # Wrap in a handler that will raise from within each() 
    # if async.close is triggered while the response is dripping by
    b = BodyWrapperWithExplicitClose.new(b)
    
    # Wrap in a handler that manages the DeferrableBody
    sender = ResponseSender.new(b)
    
    # Abort the body sending on both of those.
    env[C_async_close].callback { sender.abort! }
    env[C_async_close].errback { sender.abort! }
    env[C_async_callback].call([s, h, sender.deferrable_body])
    sender.send_next_chunk
    
    AsyncResponse # Let Thin know we are using async.*
  end
  
  private
  
  def running_with_thin?(env)
    defined?(Thin) && env[C_async_callback] && env[C_async_callback].respond_to?(:call)
  end
end
