#!/usr/bin/env ruby
#
# server_1

require 'rubygems'
require 'eventmachine'
require 'em-hiredis'
require 'em-websocket'
require 'json'

def update_country ws, redis, user, country, isSelected
    if isSelected
      redis.sadd(user, country).callback {
        redis.smembers(user).callback { |get_res|
          puts ">>> cached, set: #{get_res}"
          send_rankings ws, redis, user
        }
      }
    else
      redis.srem(user, country).callback {
        redis.smembers(user).callback { |get_res|
          puts ">>> removed, set: #{get_res}"
          send_rankings ws, redis, user
        }
      }
    end
end

def send_rankings ws, redis, user
  country_rankings = {}
  redis.keys("*").callback { |keys|
    num_keys_left = keys.length - 1
    keys.each do |k|
      if k != user.to_s
        redis.sinter(user, k).callback { |inter|
          redis.sunion(user, k).callback { |union|
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
              if num_keys_left < 1
                response = {
                  action: "country_clicked",
                  rankings: country_rankings
                }
                ws.send(response.to_json)
              end
            }
          }
        }
      end
    end
  }
end

def get_selected ws, redis, user
  redis.smembers(user).callback { |members|
    response = { action: "get_selected", selected: members }
    ws.send(response.to_json)
  }
end

EM::run do
  redis = EM::Hiredis.connect
  EM::WebSocket.run(:host => "127.0.0.1", :port => 8081) do |ws|
    ws.onopen { |handshake|
      puts "WebSocket connection open"
    }

    ws.onclose { puts "Connection closed" }

    ws.onmessage { |msg|
      puts msg
      begin
        data = JSON.parse msg
        if data["action"] == "country_clicked"
          update_country ws, redis, data["user"], data["country"], data["isSelected"]
        elsif data["action"] == "get_selected"
          get_selected ws, redis, data["user"]
        end
      rescue JSON::ParserError
        puts "failed to parse JSON!"
      end
    }
  end
end
