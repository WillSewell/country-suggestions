require 'mime-types'
require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'em-websocket'
require 'json'

require_relative 'model'
require_relative 'connection'
require_relative 'logic'

include Logic

# Simple HTTP server for serving the static files
class HttpServer < EM::Connection
  include EM::HttpServer

  def post_init
    super
    no_environment_strings
  end

  def process_http_request
    if @http_request_uri == "/"
      file = "index.html"
    else
      file = @http_request_uri[1..-1]
    end
    response = EM::DelegatedHttpResponse.new(self)
    if File.exist?(file)
      response.status = 200
      response.content_type MIME::Types.of(file).first.content_type
      response.content = File.read(file)
      response.send_response
    else
      response.status = 404
      response.send_response
    end
  end
end

# Compute rankings based on similarities to all other users
def compute_all_rankings model, user, user_countries
  # First get and loop through all other user's selections
  model.get_all_users do |users|
    # Create a callbacks by combining the proc to compute rankings with the
    # provided callback

    foreach_cb = proc do |other_user, iter|
      model.get_similarity user, user_countries, other_user do |similarity, other_countries|
        iter.return [similarity, other_countries]
      end
    end

    end_cb = proc do |similarities_and_countries|
      yield compute_rankings user_countries, similarities_and_countries
    end

    EM::Iterator.new(users, users.length).map foreach_cb, end_cb
  end
end

# Start the EM event loop to run the HTTP server and WebSocket server
EM::run do
  EventMachine.start_server("127.0.0.1", 8080, HttpServer)

  # Defines an event handler for incoming messages
  # Based on their "action" field, a different event handler will be run
  model = Model.new
  EM::WebSocket.run(:host => "127.0.0.1", :port => 8081) do |ws|
    conn = Connection.new ws
    ws.onopen { |handshake| puts "WebSocket connection open" }

    ws.onclose { puts "Connection closed" }

    ws.onmessage do |msg|
      puts msg
      begin
        data = JSON.parse msg

        compute_and_send_rankings = proc do |user_countries|
          compute_all_rankings model, data["user"], user_countries do |rankings|
            conn.send_rankings rankings
          end
        end

        if data["action"] == "country_clicked"
          model.update_country data["user"], data["country"], data["isSelected"], &compute_and_send_rankings

        elsif data["action"] == "get_selected"
          model.get_selected data["user"] do |selected|
            conn.send_selected selected
            compute_and_send_rankings.call selected
          end
        end

      rescue JSON::ParserError
        puts "failed to parse JSON!"
      end
    end
  end
end
