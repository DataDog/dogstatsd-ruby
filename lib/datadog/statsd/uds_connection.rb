# frozen_string_literal: true

require_relative 'connection'

module Datadog
  class Statsd
    class UDSConnection < Connection
      class BadSocketError < StandardError; end

      # DogStatsd unix socket path
      attr_reader :socket_path

      def initialize(socket_path, logger, telemetry)
        super(telemetry)
        @socket_path = socket_path
        @logger = logger
      end

      private

      def connect
        socket = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM)
        socket.connect(Socket.pack_sockaddr_un(@socket_path))
        socket
      end

      def send_message(message)
        socket.sendmsg_nonblock(message)
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ENOENT => e
        @socket = nil
        # TODO: FIXME: This error should be considered as a retryable error in the
        # Connection class. An even better solution would be to make BadSocketError inherit
        # from a specific retryable error class in the Connection class.
        raise BadSocketError, "#{e.class}: #{e}"
      end
    end
  end
end
