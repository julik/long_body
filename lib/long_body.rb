# The base middleware class to use in your Rack application, Sinatra, Rails etc.
#
#    use LongBody
#
# Note that if you want to use Rack::Chunked (and you most likely do) you have to insert it
# below LongBody:
#
#    use LongBody
#    use Rack::Chunked
class LongBody
  
  require_relative 'long_body/version'
  require_relative 'long_body/thin_handler'
  require_relative 'long_body/hijack_handler'
  
  class MisconfiguredBody < StandardError
    def message
      "Either Transfer-Encoding: chunked or Content-Length: <digits> must be set. " +
      "If uncertain, insert Rack::ContentLength into your middleware chain to set Content-Length " +
      "for all responses that do not pre-specify it, and Rack::Chunked to apply chunked encoding " +
      "to all responses of unknown length"
    end
  end
  
  STREAMABLE_CODES = [200, 206]
  
  def status_might_have_streamable_body?(status_code)
    STREAMABLE_CODES.include?(status_code.to_i)
  end
  
  def ensure_chunked_or_content_length!(header_hash)
    unless header_hash['Transfer-Encoding'] == 'chunked' || header_hash['Content-Length']
      raise MisconfiguredBody
    end
  end
  
  def initialize(app)
    @app = app
  end
  
  C_rack_logger = 'rack.logger'.freeze
  HIJACK_SUPPORTED = 'rack.hijack?'.freeze
  ASYNC_SUPPORT = 'async.callback'.freeze
  
  def call(env)
    # Call the upstream first
    s, h, b = @app.call(env)
    
    # If the response has nothing to do with the streaming response, just
    # let it go through as it is not big enough to bother. Also if there is no hijack
    # support there is no sense to bother at all.
    return [s, h, b] unless status_might_have_streamable_body?(s)
    
    # If the body is nil or is not each-able, return the original response - there probably is some other
    # async trickery going on downstream from us, and we should not intercept this response.
    return [s, h, b] if (b.nil? || !b.respond_to?(:each) || (b.respond_to?(:empty?) && b.empty?))
    
    # Ensure either Content-Length or chunking is in place
    ensure_chunked_or_content_length!(h)
    
    # TODO: ensure not already hijacked
    
    if env[ASYNC_SUPPORT]
      env[C_rack_logger].info("Streaming via async.callback (Thin)") if env[C_rack_logger].respond_to?(:info)
      ThinHandler.perform(env, s, h, b)
    elsif env[HIJACK_SUPPORTED]
      env[C_rack_logger].info("Streaming via hijack and IO.select") if env[C_rack_logger].respond_to?(:info)
      HijackHandler.perform(env, s, h, b)
    else
      [s, h, b] # No recourse
    end
  end
end
