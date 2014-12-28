#!/usr/bin/env ruby
#
# server_1

require 'rubygems'
require 'eventmachine'
require 'em-hiredis'
require 'em-websocket'
require 'json'

EM::run do
  redis = EM::Hiredis.connect
  EM::WebSocket.run(:host => "127.0.0.1", :port => 8081) do |ws|
    ws.onopen { |handshake|
      puts "WebSocket connection open"
    }

    ws.onclose { puts "Connection closed" }

    ws.onmessage { |msg|
      begin
        data = JSON.parse msg
        if data["isSelected"]
          redis.sadd(data["user"], data["country"]).callback {
            redis.smembers(data["user"]).callback { |get_res|
              ws.send ">>> cached, set: #{get_res}"
            }
          }
        else
          redis.srem(data["user"], data["country"]).callback {
            redis.smembers(data["user"]).callback { |get_res|
              ws.send ">>> removed, set: #{get_res}"
            }
          }
        end
      rescue JSON::ParserError
        ws.send "failed to parse JSON!"
      end
    }
  end
end
