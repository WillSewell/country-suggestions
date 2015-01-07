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
    redis.sadd(user, country).callback do
      redis.smembers(user).callback do |get_res|
        puts ">>> cached, set: #{get_res}"
        send_rankings ws, redis, user, get_res
      end
    end
  else
    redis.srem(user, country).callback do
      redis.smembers(user).callback do |get_res|
        puts ">>> removed, set: #{get_res}"
        send_rankings ws, redis, user, get_res
      end
    end
  end
end

# Compute rankings based on similarities to all other users
def send_rankings ws, redis, user, user_countries
  country_rankings = {}
  max_ranking = 0
  # First get and loop through other users selections
  redis.keys("*").callback do |keys|
    num_keys_left = keys.length - 1
    keys.each do |k|
      if k != user.to_s
        # For each other user, compute the similarity using the Jaccard index
        redis.smembers(k).callback do |other_countries|
          inter = user_countries & other_countries
          union = user_countries | other_countries
          similarity = inter.length.to_f / union.length
          # For each country of the other user, increase the rank of
          # that country based on the similarity
          puts k + other_countries.inspect
          puts k + inter.inspect
          puts k + union.inspect
          puts k + similarity.inspect
          if similarity > 0
            other_countries.each do |other_country|
              unless user_countries.include? other_country
                found = false
                country_rankings.each do |ranked_country, rank|
                  if ranked_country == other_country
                    # No need to suggest countries already selected
                    country_rankings[other_country] += similarity
                    found = true
                  end
                end
                unless found
                  country_rankings[other_country] = similarity
                end
                if country_rankings[other_country] > max_ranking
                  max_ranking = country_rankings[other_country]
                end
              end
            end
          end
          puts k + " " + country_rankings.inspect
          # If all other users of been looked at, send the similarities
          # TODO: need to think of race conditions here with num_keys_left
          num_keys_left -= 1
          if num_keys_left < 1
            # normalise
            country_rankings.each do |country, rank|
              country_rankings[country] = rank / max_ranking # normalize
            end
            response = {
              action: "country_clicked",
              rankings: country_rankings,
            }
            ws.send(response.to_json)
          end
        end
      end
    end
  end
end

# Get all selected countries for a given user
def get_selected ws, redis, user
  redis.smembers(user).callback do |members|
    response = { action: "get_selected", selected: members }
    ws.send(response.to_json)
    # Also send the rankings
    send_rankings ws, redis, user, members
  end
end

# Start the EM event loop
# Defines an event handler for incoming messages
# Based on their "action" field, a different event handler will be run
EM::run do
  redis = EM::Hiredis.connect
  EM::WebSocket.run(:host => "127.0.0.1", :port => 8081) do |ws|
    ws.onopen { |handshake| puts "WebSocket connection open" }

    ws.onclose { puts "Connection closed" }

    ws.onmessage do |msg|
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
    end
  end
end
