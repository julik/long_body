# The problem with fast each() bodies is that the Ruby process will
# enter a busy wait if the write socket for the webserver is saturated.
#
# We can bypass that by releasing the CPU using a select(), but for that
# we have to use "rack.hijack" in combination with a nonblocking write.
#
# For more on this:
# http://apidock.com/ruby/IO/write_nonblock
# http://old.blog.phusion.nl/2013/01/23/the-new-rack-socket-hijacking-api/
#
# By using this class as a middleware you will put a select() wait
# spinlock on the output socket of the webserver.
#
# The middleware will only trigger for 200 and 206 responses, and only
# if the Rack handler it is running on supports rack hijacking.
module LongBody::HijackHandler
  extend self
  HIJACK_HEADER = 'rack.hijack'.freeze
  
  def perform(env, s, h, b)
    # Replace the output with our socket moderating technology 2.0
    h[HIJACK_HEADER] = create_socket_writer_lambda_with_body(b)
    [s, h, []] # Recommended response body for partial hijack is an empty Array
  end
  
  def create_socket_writer_lambda_with_body(rack_response_body)
    lambda do |socket|
      begin
        rack_response_body.each do | chunk |
          begin
            num_bytes_written = socket.write_nonblock(chunk)
            # If we could write only partially, make sure we do a retry on the next
            # iteration with the remaining part
            if num_bytes_written < chunk.bytesize
              chunk = chunk[num_bytes_written..-1]
              raise Errno::EINTR
            end
          rescue IO::WaitWritable, Errno::EINTR # The output socket is saturated.
            # If we are running within a threaded server, 
            # let another thread preempt here. We are waiting for IO
            # and some other thread might have things to do here.
            IO.select(nil, [socket]) # ...then wait on the socket to be writable again
            retry # and off we go...
          rescue Errno::EPIPE, Errno::EPROTOTYPE # Happens when the client aborts the connection
            return
          end
        end
      ensure
        rack_response_body.close if rack_response_body.respond_to?(:close)
        socket.close if socket.respond_to?(:closed?) && socket.respond_to?(:close) && !socket.closed?
      end
    end
  end
end
