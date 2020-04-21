# frozen_string_literal: true

module Datadog
  class Statsd
    class MessageBuffer
      def initialize(connection,
        max_buffer_payload_size:,
        max_buffer_pool_size:,
        buffer_overflowing_stategy: :drop
      )
        @connection = connection
        @max_buffer_payload_size = max_buffer_payload_size
        @max_buffer_pool_size = max_buffer_pool_size
        @buffer_overflowing_stategy = buffer_overflowing_stategy

        @buffer = String.new
        @message_count = 0

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
        inner_message_count = message.count("\n") + 1

        return nil unless ensure_sendable!(message_size)

        unless buffer.empty?
          if should_flush?(message_size, inner_message_count)
            flush
          else
            buffer << "\n"
          end
        end

        buffer << message
        @message_count += inner_message_count
        true
      end

      def flush
        return if buffer.empty?

        connection.write(@buffer)

        buffer.clear
        @message_count = 0
      end

      private
      attr :max_buffer_payload_size
      attr :max_buffer_pool_size

      attr :buffer_overflowing_stategy

      attr :connection
      attr :buffer

      def should_flush?(message_size, inner_message_count)
        return true if buffer.bytesize + 1 + message_size >= max_buffer_payload_size
        return true if @message_count + inner_message_count >= max_buffer_pool_size

        false
      end

      def ensure_sendable!(message_size)
        return true if message_size <= max_buffer_payload_size

        if buffer_overflowing_stategy == :raise
          raise Error, 'Message too big for payload limit'
        end

        false
      end
    end
  end
end
