# frozen_string_literal: true

module Datadog
  class Statsd
    class MessageBuffer
      def initialize(connection, max_buffer_payload_size:)
        @connection = connection
        @max_buffer_payload_size = max_buffer_payload_size

        @buffer = String.new

        @depth = 0
      end

      def open
        @depth += 1

        yield
      ensure
        @depth -= 1
        flush if !open?
      end

      def open?
        @depth > 0
      end

      def add(message)
        message_size = message.bytesize

        unless buffer.empty?
          if should_flush?(message_size)
            flush
          else
            buffer << "\n"
          end
        end

        buffer << message
      end

      def flush
        return if @buffer.empty?

        @connection.write(@buffer)

        buffer.clear
      end

      private
      attr :max_buffer_payload_size

      attr :buffer

      def should_flush?(message_size)
        buffer.bytesize + 1 + message_size >= max_buffer_payload_size
      end
    end
  end
end
