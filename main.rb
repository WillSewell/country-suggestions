#!/usr/bin/env ruby
#
# server_1

require 'rubygems'
require 'eventmachine'
require 'em-hiredis'
require 'em-websocket'
require 'json'

# Add, or delete a country, and then compute and send rankings
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

# Compute rankings based on similarities to all other users
def send_rankings ws, redis, user
  country_rankings = {}
  # First get and loop through other users selections
  redis.keys("*").callback do |keys|
    num_keys_left = keys.length - 1
    keys.each do |k|
      if k != user.to_s
        # For each other user, compute the similarity using the Jaccard index
        redis.sinter(user, k).callback do |inter|
          redis.sunion(user, k).callback do |union|
            similarity = inter.length.to_f / union.length
            # For each country of the other user, increase the rank of
            # that country based on the similarity
            redis.smembers(k).callback do |other_user_countries|
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
              # If all other users of been looked at, send the similarities
              # TODO: need to think of race conditions here with num_keys_left
              num_keys_left -= 1
              if num_keys_left < 1
                response = {
                  action: "country_clicked",
                  rankings: country_rankings
                }
                ws.send(response.to_json)
              end
            end
          end
        end
      end
    end
  end
end

# Get all selected countries for a given user
def get_selected ws, redis, user
  redis.smembers(user).callback { |members|
    response = { action: "get_selected", selected: members }
    ws.send(response.to_json)
  }
end

# Start the EM event loop
# Defines an event handler for incoming messages
# Based on their "action" field, a different event handler will be run
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
