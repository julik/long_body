module TestDownload
  extend self
  Part = Struct.new(:time_difference, :payload)
  def perform(uri)
    response_chunks = []
    uri = URI(uri.to_s)
    conn = Net::HTTP.new(uri.host, uri.port)
    conn.read_timeout = 120 # Might take LONG
    conn.start do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      before_first = Time.now
      http.request(req) do |res|
        res.read_body do |chunk|
          diff = (Time.now - before_first).to_f
          response_chunks << Part.new(diff, chunk)
        end
      end
    end
    response_chunks
  end
  
  def perform_and_abort_after_3_chunks(uri)
    response_chunks = []
    catch :abort do
      uri = URI(uri.to_s)
      conn = Net::HTTP.new(uri.host, uri.port)
      conn.read_timeout = 120 # Might take LONG
      conn.start do |http|
        req = Net::HTTP::Get.new(uri.request_uri)
        before_first = Time.now.to_i
        http.request(req) do |res|
          res.read_body do |chunk|
            diff = Time.now.to_i - before_first
            response_chunks << Part.new(diff, chunk)
            throw :abort if response_chunks.length == 3
          end
        end
      end
    end
    response_chunks
  end
end