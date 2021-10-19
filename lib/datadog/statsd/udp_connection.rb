# frozen_string_literal: true

require_relative 'connection'

module Datadog
  class Statsd
    class UDPConnection < Connection
      DEFAULT_HOST = '127.0.0.1'
      DEFAULT_PORT = 8125

      # StatsD host. Defaults to 127.0.0.1.
      attr_reader :host

      # StatsD port. Defaults to 8125.
      attr_reader :port

      def initialize(host, port, **kwargs)
        super(**kwargs)

        @host = host || ENV.fetch('DD_AGENT_HOST', DEFAULT_HOST)
        @port = port || ENV.fetch('DD_DOGSTATSD_PORT', DEFAULT_PORT).to_i
        @socket = nil
      end

      def close
        @socket.close if @socket
        @socket = nil
      end

      private

      def connect
        close if @socket

        @socket = UDPSocket.new
        @socket.connect(host, port)
      end

      # send_message is writing the message in the socket, it may create the socket if nil
      # It is not thread-safe but since it is called by either the Sender bg thread or the
      # SingleThreadSender (which is using a mutex while Flushing), only one thread should call
      # it at a time.
      def send_message(message)
        connect unless @socket
        @socket.send(message, 0)
      end
    end
  end
end
