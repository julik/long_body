TEST_RACK_APP = File.join(File.dirname(File.expand_path(__FILE__)), '..', 'streaming_app.ru')

class RunningServer < Struct.new(:name, :command, :port)
  def command
    super % [port, TEST_RACK_APP]
  end
   
  def start!
    # Boot Puma in a forked process
    full_path = File.join(File.dirname(File.expand_path(__FILE__)), 'streaming_app.ru')
    @pid = fork do
      puts "Spinning up with #{command.inspect}"
      # Do not pollute the RSpec output with the Puma logs, save the stuff
      # to the logfiles instead
      $stdout.reopen(File.open('%s_output.log' % name, 'a'))
      $stderr.reopen(File.open('%s_output.log' % name, 'a'))
      
      # Since we have to do with timing tolerances, having the output drip in ASAP is useful
      $stdout.sync = true
      $stderr.sync = true
      exec(command)
    end
    
    Thread.new do
      # Wait for Puma to be online, poll the alive URL until it stops responding
      loop do
        sleep 0.5
        begin
          this_server_url = "http://0.0.0.0:%d/alive" % port
          TestDownload.perform(this_server_url)
          puts "#{name} is alive!"
          @running = true
          break
        rescue Errno::ECONNREFUSED
        end
      end
    end
    
    trap("TERM") { stop! }
  end
  
  def running?
    !!@running
  end
  
  def stop!
    return unless @pid
    
    # Tell the webserver to quit, twice (we do not care if there are running responses)
    %W( TERM TERM KILL ).each {|sig| Process.kill(sig, @pid); sleep 0.5 }
    @pid = nil
  end
end

SERVERS = [
  RunningServer.new(:puma, "bundle exec puma --port %d %s", 9393),
  RunningServer.new(:thin, "bundle exec thin --port %d --rackup %s start", 9394),
  RunningServer.new(:rainbows, "bundle exec rainbows --port %d %s", 9395),
  RunningServer.new(:passenger, "bundle exec passenger start  --port %d --rackup %s", 9396),
  RunningServer.new(:unicorn, "bundle exec unicorn --port %d %s", 9397),
]

