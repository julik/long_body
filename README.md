# long_body

[![Build Status](https://travis-ci.org/julik/long_body.svg?branch=master)](https://travis-ci.org/julik/long_body)

Universal Rack middleware for immediate (after-headers) streaming of long Rack response bodies.
Normally most Rack handler webservers will buffer your entire response, or buffer your response
without telling you for some time before sending it.

This module provides a universal wrapper that will use the features of a specific webserver
to send your response with as little buffering as possible (direct to socket). For decent
servers that allow `rack.hijack` it will use that, for Thin it will use deferrables.

Note that within Thin sleeping in a long body might block the EM loop.

## Usage examples

Server-sent events combined with `Transfer-Encoding: chunked` (can be used for chat applications and so forth):

    class EventSource
      def each
        20.times do | event_num |
          yield "event: ping\n"
          yield "data: ping_number_#{event_num}"
          yield "\n\n"
          sleep 3
        end
      end
    end
    
    # config.ru
    use LongBody
    use Rack::Chunked
    run ->(env) {
      h = {'Content-Type' => 'text/event-stream'}
      [200, h, EventSource.new]
    }

Streaming a large file, without buffering:

    # config.ru
    use LongBody
    run ->(env) {
      s = File.size("/tmp/large_file.bin")
      h = {'Content-Length' => s}
      [200, h, File.open(s, 'rb')]
    }

## Selective bypass

Most requests in your application (assets, HTML pages and so on) probably do not need this and are better to be sent as-is.
Also, such processing will likely bypass all HTTP caching you set up. `long_body` is "always on" by default. To bypass it,
send `X-Rack-Long-Body-Skip` header with any truthy contents in your response headers (better use a string value so that
`Rack::Lint` does not complain).

## Compatibility

This gem is tested on Ruby 2.2, and should run acceptably well on Ruby 2.+. If you are using Thin it is recommended to
use Ruby 2.+ because of the fiber stack size limitation. If you are using Puma, Rainbows or other threaded
server running this gem on 1.9.3+ should be possible as well.

<table>
  <tr><th>Webserver</th><th>Version tested</th><th>Compatibility</th></tr>
  <tr><td>Puma</td><td>2.13.4</td><td>Yes (use versions >= 2.13.4 due to a bug)</td></tr>
  <tr><td>Passenger</td><td>5.0.15</td><td>Yes</td></tr>
  <tr><td>Thin</td><td>1.6.3</td><td>Yes</td></tr>
  <tr><td>Rainbows</td><td>4.6.2</td><td>Yes</td></tr>
  <tr><td>WEBrick</td><td>stdlib 2.2.1</td><td>No (uses IO.pipe for hijack)</td></tr>
</table>

## Contributing to long_body
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2015 Julik Tarkhanov. See LICENSE.txt for
further details.

