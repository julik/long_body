$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'long_body'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.order = 'random'
  config.before :suite do
    $postrun = StringIO.new
    $postrun << "\n\n"
    
    SERVERS.each(&:start!)
    
    sleep 0.5 until SERVERS.all?(&:running?)
  end
  
  config.before :each do
    FileUtils.rm('/tmp/streamer_messages.log') if File.exist?('/tmp/streamer_messages.log')
    FileUtils.rm('/tmp/streamer_close.log') if File.exist?('/tmp/streamer_close.log')
  end
  
  config.after :suite do
    SERVERS.each(&:stop!)
    puts $postrun.string
  end
end
