# Lifted from https://github.com/macournoyer/thin_async/blob/master/lib/thin/async.rb
# and originally written by James Tucker <raggi@rubyforge.org>
class LongBody::DeferrableBody
  include EM::Deferrable

  def initialize
    @queue = []
  end

  def call(body)
    @queue << body
    schedule_dequeue
  end

  def each(&blk)
    @body_callback = blk
    schedule_dequeue
  end

  private
  
  def schedule_dequeue
    return unless @body_callback
    EM.next_tick do
      next unless body = @queue.shift
      body.each do |chunk|
        @body_callback.call(chunk)
      end
      schedule_dequeue unless @queue.empty?
    end
  end
end