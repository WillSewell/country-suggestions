#!/usr/bin/env ruby
#
# server_1

require 'rubygems'
require 'eventmachine'
require 'em-hiredis'
require 'json'

class EchoServer < EventMachine::Connection
  def initialize
    @redis = EM::Hiredis.connect
  end

  def post_init
    puts "-- someone connected to the server!"
  end

  def receive_data raw
    data = JSON.parse raw
    @redis.sadd(data["user"], data["country"]).callback {
      @redis.smembers(data["user"]).callback { |get_res|
        send_data ">>> cached: #{get_res}"
      }
    }
  end
end

EventMachine::run do
  EventMachine::start_server "127.0.0.1", 8081, EchoServer
  puts 'running echo server on 8081'
end
