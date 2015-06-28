# Rack::Lint bails on async.callback responses. "Fix" it to bypass
# if running within Thin and when async.callback is available.
module Rack
  class Lint
    THIN_RE = /^thin/.freeze
    def call(env=nil)
      if env && env['async.callback'] && env['SERVER_SOFTWARE'].to_s =~ THIN_RE
        @app.call(env)
      else
        dup._call(env)
      end
    end
  end
end
