# frozen_string_literal: true

module Datadog
  class Statsd
    class MessageBuffer
      PAYLOAD_SIZE_TOLERANCE = 0.05

      def initialize(connection,
        max_payload_size: nil,
        max_pool_size: DEFAULT_BUFFER_POOL_SIZE,
        overflowing_stategy: :drop
      )
        raise ArgumentError, 'max_payload_size keyword argument must be provided' unless max_payload_size
        raise ArgumentError, 'max_pool_size keyword argument must be provided' unless max_pool_size

        @connection = connection
        @max_payload_size = max_payload_size
        @max_pool_size = max_pool_size
        @overflowing_stategy = overflowing_stategy

        @buffer = String.new
        @message_count = 0

        # store the pid for which this message buffer has been created
        update_fork_pid
      end

      def add(message)
        # we are in a new PID, which means the parent process has just forked and
        # we are currently running in the child: we have to clean the buffer since
        # we don't want to process/flush the metrics buffered by the parent process.
        if forked?
          reset
          update_fork_pid
        end

        message_size = message.bytesize

        return nil unless message_size > 0 # to avoid adding empty messages to the buffer
        return nil unless ensure_sendable!(message_size)

        flush if should_flush?(message_size)

        buffer << "\n" unless buffer.empty?
        buffer << message

        @message_count += 1

        # flush when we're pretty sure that we won't be able
        # to add another message to the buffer
        flush if preemptive_flush?

        true
      end

      def reset
        buffer.clear
        @message_count = 0
      end

      def flush
        return if buffer.empty?

        connection.write(buffer)
        reset
      end

      private
      attr :max_payload_size
      attr :max_pool_size

      attr :overflowing_stategy

      attr :connection
      attr :buffer

      def should_flush?(message_size)
        return true if buffer.bytesize + 1 + message_size >= max_payload_size

        false
      end

      def preemptive_flush?
        @message_count == max_pool_size || buffer.bytesize > bytesize_threshold
      end

      def ensure_sendable!(message_size)
        return true if message_size <= max_payload_size

        if overflowing_stategy == :raise
          raise Error, 'Message too big for payload limit'
        end

        false
      end

      def bytesize_threshold
        @bytesize_threshold ||= (max_payload_size - PAYLOAD_SIZE_TOLERANCE * max_payload_size).to_i
      end

      # below are "fork management" methods to be able to clean the MessageBuffer
      # if it detects that it is running in a unknown PID.

      def forked?
        Process.pid != fork_pid
      end

      def update_fork_pid
        @fork_pid = Process.pid
      end

      def fork_pid
        @fork_pid ||= Process.pid
      end
    end
  end
end
