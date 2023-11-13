# frozen_string_literal: true

require_relative 'connection'
require "resolv"

module Datadog
  class Statsd
    class UDPConnection < Connection
      # StatsD host.
      attr_reader :host

      # StatsD port.
      attr_reader :port


      def self.resolve_host_dns(hostname)
        Resolv::DNS.open do |dns|
          dns.timeouts = 1
          dns.getaddress(hostname)
        end
      rescue Resolv::ResolvError
        nil
      end

      def initialize(host, port, **kwargs)
        super(**kwargs)

        @host = host
        @host_is_ip = !!(@host =~ Regexp.union([Resolv::IPv4::Regex, Resolv::IPv6::Regex]))
        @port = port
        @socket = nil
      end

      def close
        @socket.close if @socket
        @socket = nil
      end

      private

      def connect
        close if @socket

        family = Addrinfo.udp(host, port).afamily

        @socket = UDPSocket.new(family)
        @socket.connect(host, port)
      end

      def check_dns_resolution
        return if @host_is_ip
        return if @last_dns_check && Time.now - @last_dns_check < 60
        
        @last_dns_check = Time.now
        fresh_resolved_ip = self.class.resolve_host_dns(@host) 
        @current_host_ip = fresh_resolved_ip unless defined?(@current_host_ip)

        return if @current_host_ip == fresh_resolved_ip

        @current_host_ip = fresh_resolved_ip
        close
        connect
      rescue Resolv::ResolvError
        nil
      end

      # send_message is writing the message in the socket, it may create the socket if nil
      # It is not thread-safe but since it is called by either the Sender bg thread or the
      # SingleThreadSender (which is using a mutex while Flushing), only one thread must call
      # it at a time.
      def send_message(message)
        connect unless @socket
        check_dns_resolution
        @socket.send(message, 0)
      end
    end
  end
end
