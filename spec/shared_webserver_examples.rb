RSpec.shared_examples "compliant" do
  it "when the response is sent in full works with predefined Content-Length" do | example |
    parts = TestDownload.perform("http://0.0.0.0:#{port}/with-content-length")
    timings = parts.map(&:time_difference)
    
#   $postrun.puts ""
#   $postrun.puts "#{example.full_description} part receive timings: #{timings.inspect}"
#   $postrun.puts ""

    expect(File).to exist('/tmp/streamer_close.mark')
  
    # Ensure the time recieved of each part is within the tolerances, and certainly
    # at least 1 second after the previous
    (1..(parts.length-1)).each do | part_i|
      this_part = parts[part_i]
      previous_part = parts[part_i -1]
      received_after_previous = this_part.time_difference - previous_part.time_difference
      
      # Ensure there was some time before this chunk arrived. This is the most important test.
      expect(received_after_previous).to be_within(1).of(0.3)
    end
  end

  it 'when the response is sent in full works with chunked encoding' do | example |
    parts = TestDownload.perform("http://0.0.0.0:#{port}/chunked")
    timings = parts.map(&:time_difference)
    
#    $postrun.puts example.full_description
#    $postrun.puts "Part receive timings: #{timings.inspect}"
#    $postrun.puts ""
    
    expect(File).to exist('/tmp/streamer_close.mark')
  
    (1..(parts.length-1)).each do | part_i|
      this_part = parts[part_i]
      previous_part = parts[part_i -1]
      received_after_previous = this_part.time_difference - previous_part.time_difference
      
      # Ensure there was some time before this chunk arrived. This is the most important test.
      expect(received_after_previous).to be_within(1).of(0.3)
    end
  end
  
  it 'raises an error if no Content-Length or chunked transfer encoding is set' do
    parts = TestDownload.perform("http://0.0.0.0:#{port}/error-with-unclassified-body")
    response_body = parts.join
    expect(response_body).to include('If uncertain, insert Rack')
  end
  
  it 'when the HTTP client process is killed midflight, does not read more chunks from the body object' do
    # This test checks whether the server makes the iterable body complete if the client closes the connection
    # prematurely. If you have the callbacks set up wrong on Thin, for instance, it will read the response
    # completely and potentially buffer it in memory, filling up your RAM. We need to ensure that the server
    # uses it's internal mechanics to stop reading the body once the client is dropped.
    pid = fork do
      TestDownload.perform("http://0.0.0.0:#{port}/with-content-length")
    end
    sleep(1)
    Process.kill("KILL", pid)
    
    # Wait for the webserver to terminate operations on that request (the close()
    # call on the body is usually not immediate, but gets executed once the write
    # to the client socket fails).
    sleep 0.9
    
    written_parts_list = File.read("/tmp/streamer_messages.log").split("\n")
    expect(written_parts_list.length).to be < 6
    
    expect(File).to exist('/tmp/streamer_close.mark')
  end
end

