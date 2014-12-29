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
              puts ">>> cached, set: #{get_res}"
            }
          }
        else
          redis.srem(data["user"], data["country"]).callback {
            redis.smembers(data["user"]).callback { |get_res|
              puts ">>> removed, set: #{get_res}"
            }
          }
        end
      rescue JSON::ParserError
        ws.send "failed to parse JSON!"
      end
      country_rankings = {}
      redis.keys("*").callback { |keys|
        num_keys_left = keys.length
        keys.each do |k|
          if k != data["user"]
            redis.sinter(data["user"], k).callback { |inter|
              redis.sunion(data["user"], k).callback { |union|
                similarity = inter.length.to_f / union.length
                redis.smembers(k).callback { |other_user_countries|
                  other_user_countries.each do |country|
                    found = false
                    country_rankings.each do |other_country, rank|
                      if other_country == country
                        rank += similarity
                        found = true
                      end
                    end
                    if !found
                      country_rankings[country] = similarity
                    end
                  end
                  num_keys_left -= 1
                  if num_keys_left > 0
                    ws.send(country_rankings.to_json)
                  end
                }
              }
            }
          end
        end
      }
    }
  end
end
