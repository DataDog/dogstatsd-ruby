# frozen_string_literal: true

require_relative 'connection'

module Datadog
  class Statsd
    class UDPConnection < Connection
      def initialize(host, port, logger, telemetry)
        super(telemetry)
        @host = host || ENV.fetch('DD_AGENT_HOST', nil) || DEFAULT_HOST
        @port = port || ENV.fetch('DD_DOGSTATSD_PORT', nil) || DEFAULT_PORT
        @logger = logger
      end

      private

      def connect
        socket = UDPSocket.new
        socket.connect(@host, @port)
        socket
      end

      def send_message(message)
        socket.send(message, 0)
      end
    end
  end
end
