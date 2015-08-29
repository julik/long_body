require File.expand_path(File.dirname(__FILE__) + '/../lib/long_body')

require 'fileutils'
# The test app
class Streamer
  
  class TestBody
    def each
      File.open("/tmp/streamer_messages.log", "w") do |f|
        25.times do |i|
          sleep 0.3
          yield "Message number #{i}"
          f.puts(i)
          f.flush # Make sure it is on disk
        end
      end
    end
    
    def close
      FileUtils.touch('/tmp/streamer_close.mark')
    end
  end
  
  def self.call(env)
    # The absence of Content-Length will trigger Rack::Chunking into work automatically.
    [200, {'Content-Type' => 'text/plain'}, TestBody.new]
  end
end

class StreamerWithLength < Streamer
  def self.call(env)
    s, h, b = super
    [s, h.merge('Content-Length' => '415'), b]
  end
end

map '/error-with-unclassified-body' do
  use Rack::ShowExceptions
  use LongBody
  run ->(env) { [200, {}, %w( one two three )]}
end

map '/chunked' do
  use LongBody
  use Rack::Chunked
  run Streamer
end

map '/with-content-length-without-long-body' do
  run StreamerWithLength
end

class Skipper < Struct.new(:app)
  def call(env)
    s, h, b = app.call(env)
    [s, h.merge('X-Rack-Long-Body-Skip' => 'yes'), b]
  end
end

map '/explicitly-skipping-long-body' do
  use LongBody
  use Skipper
  run Streamer
end

map '/with-content-length' do
  use LongBody
  run StreamerWithLength
end

map '/alive' do
  run ->(env) { [200, {}, ['Yes']]}
end
