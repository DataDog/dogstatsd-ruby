# frozen_string_literal: true

module Datadog
  class Statsd
    class Connection
      def initialize(telemetry: nil, logger: nil)
        @telemetry = telemetry
        @logger = logger
      end

      # Close the underlying socket
      def close
        begin
          @socket && @socket.close if instance_variable_defined?(:@socket)
        rescue StandardError => boom
          logger.error { "Statsd: #{boom.class} #{boom}" } if logger
        end
        @socket = nil
      end

      def write(payload)
        logger.debug { "Statsd: #{payload}" } if logger

        send_message(payload)

        telemetry.sent(packets: 1, bytes: payload.length) if telemetry

        true
      rescue StandardError => boom
        # Try once to reconnect if the socket has been closed
        retries ||= 1
        if retries <= 1 &&
          (boom.is_a?(Errno::ENOTCONN) or
           boom.is_a?(Errno::ECONNREFUSED) or
           boom.is_a?(IOError) && boom.message =~ /closed stream/i)
          retries += 1
          begin
            close
            retry
          rescue StandardError => e
            boom = e
          end
        end

        telemetry.dropped(packets: 1, bytes: payload.length) if telemetry
        logger.error { "Statsd: #{boom.class} #{boom}" } if logger
        nil
      end

      private
      attr_reader :telemetry
      attr_reader :logger

      def socket
        @socket ||= connect
      end
    end
  end
end
