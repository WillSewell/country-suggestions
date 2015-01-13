#!/usr/bin/env ruby
#
# server_1

require 'rubygems'
require 'eventmachine'
require 'em-hiredis'
require 'em-websocket'
require 'json'

# Add, or delete a country, and then compute and send rankings
def update_country redis, user, country, isSelected, callback
  # Run the callback on the new set of countries
  cb = proc do |x|
    redis.smembers(user, country).callback do |user_countries|
      callback.call user_countries
    end
  end
  if isSelected
    redis.sadd(user, country).callback cb
  else
    redis.srem(user, country).callback cb
  end
end

compute_similarities = proc do |redis, user, user_countries, other_user, iter|
  if other_user == user.to_s
    # We don't care about the similarity of the current user to themselves
    # Just return a dummy value with similarity 0 so it is not counted
    iter.return [0, []]
  else
    # For each other user, compute the similarity using the Jaccard index
    redis.smembers(other_user).callback do |other_countries|
      inter = user_countries & other_countries
      union = user_countries | other_countries
      similarity = inter.length.to_f / union.length
      iter.return [similarity, other_countries]
    end
  end
end

compute_rankings = proc do |user_countries, similarities_and_countries|
  # For each country of the other user, increase the rank of
  # that country based on the similarity
  rankings_and_max = similarities_and_countries.reduce([{}, 0]) do |acc, similarity_and_countries|
    similarity = similarity_and_countries[0]
    other_user_countries = similarity_and_countries[1]
    country_rankings = acc[0]
    max_ranking = acc[1]
    if similarity > 0
      other_user_countries.each do |other_user_country|
        # Don't bother suggesting countries they have already clicked
        unless user_countries.include? other_user_country
          found = false
          country_rankings.each do |ranked_country, rank|
            if ranked_country == other_user_country
              # No need to suggest countries already selected
              country_rankings[other_user_country] += similarity
              found = true
            end
          end
          unless found
            country_rankings[other_user_country] = similarity
          end
          if country_rankings[other_user_country] > max_ranking
            max_ranking = country_rankings[other_user_country]
          end
        end
      end
    end
    [country_rankings, max_ranking]
  end
  normalise_rankings rankings_and_max[0], rankings_and_max[1]
end

def normalise_rankings rankings, max_ranking
  Hash[rankings.map do |country, rank|
    [country, rank / max_ranking ]
  end]
end

# Compute rankings based on similarities to all other users
compute_all_rankings = proc do |redis, user, callback, user_countries|
  # First get and loop through all other user's selections
  redis.keys("*").callback do |keys|
    # Create a callback by combining the proc to compute rankings with the
    # provided callback
    cb = proc do |similarities_and_countries|
      callback.call (compute_rankings.call user_countries, similarities_and_countries)
    end
    EM::Iterator.new(keys, keys.length).map(compute_similarities.curry[redis][user][user_countries], cb)
  end
end

send_rankings = proc do |ws, rankings|
  response = {
    action: "country_clicked",
    rankings: rankings,
  }
  ws.send(response.to_json)
end

# Get all selected countries for a given user
def send_selected ws, redis, user, callback
  redis.smembers(user).callback do |members|
    response = { action: "get_selected", selected: members }
    ws.send(response.to_json)
    callback.call members
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
        # Chaining callbacks -- executed in reverse
        send_rankings_cb = send_rankings.curry[ws]
        compute_rankings_cb = compute_all_rankings.curry[redis][data["country"]][send_rankings_cb]
        p compute_rankings_cb
        if data["action"] == "country_clicked"
          update_country redis, data["user"], data["country"], data["isSelected"], compute_rankings_cb
        elsif data["action"] == "get_selected"
          send_selected ws, redis, data["user"], compute_rankings_cb
        end
      rescue JSON::ParserError
        puts "failed to parse JSON!"
      end
    end
  end
end
