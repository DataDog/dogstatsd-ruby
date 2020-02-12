# frozen_string_literal: true

module Datadog
  class Statsd
    class Connection
      def initialize(telemetry)
        @telemetry = telemetry
      end

      # Close the underlying socket
      def close
        @socket && @socket.close
      end

      def write(message)
        logger.debug { "Statsd: #{message}" } if logger
        payload = message + telemetry.flush
        send_message(payload)

        telemetry.reset
        telemetry.bytes_sent += payload.length
        telemetry.packets_sent += 1
      rescue StandardError => boom
        # Try once to reconnect if the socket has been closed
        retries ||= 1
        if retries <= 1 &&
          (boom.is_a?(Errno::ENOTCONN) or
           boom.is_a?(Errno::ECONNREFUSED) or
           boom.is_a?(IOError) && boom.message =~ /closed stream/i)
          retries += 1
          begin
            @socket = connect
            retry
          rescue StandardError => e
            boom = e
          end
        end

        telemetry.bytes_dropped += payload.length
        telemetry.packets_dropped += 1
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
