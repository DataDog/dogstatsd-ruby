# frozen_string_literal: true

module Datadog
  class Statsd
    class MessageBuffer
      PAYLOAD_SIZE_TOLERANCE = 0.05

      def initialize(connection,
        max_payload_size: nil,
        max_pool_size: DEFAULT_BUFFER_POOL_SIZE,
        overflowing_stategy: :drop,
        flush_interval: nil
      )
        raise ArgumentError, 'max_payload_size keyword argument must be provided' unless max_payload_size
        raise ArgumentError, 'max_pool_size keyword argument must be provided' unless max_pool_size

        @connection = connection
        @max_payload_size = max_payload_size
        @max_pool_size = max_pool_size
        @overflowing_stategy = overflowing_stategy
        @flush_interval = flush_interval

        # This monitor prevents the buffer from being cleared by a thread while it is beging
        # flushed by another thread, or the threads from writing the socket at the same time.
        # One thread is "Statsd Sender" and the other is "Statsd MessageBuffer."
        @mon = Monitor.new
        @cv = @mon.new_cond
        @closed = false

        @buffer = String.new
        clear_buffer

        @flush_thread = create_flush_thread if @flush_interval
      end

      def add(message)
        message_size = message.bytesize

        return nil unless message_size > 0 # to avoid adding empty messages to the buffer
        return nil unless ensure_sendable!(message_size)

        @mon.synchronize {
          raise Error, 'buffer is closed' if @closed
          flush if should_flush?(message_size)

          buffer << "\n" unless buffer.empty?
          buffer << message

          @message_count += 1

          # flush when we're pretty sure that we won't be able
          # to add another message to the buffer
          flush if preemptive_flush?
        }

        true
      end

      def reset
        @mon.synchronize {
          close
          connection.reset_telemetry
          @flush_thread = create_flush_thread if @flush_interval
          @closed = false
        }
      end

      def flush
        @mon.synchronize {
          return if buffer.empty?

          connection.write(buffer)
          clear_buffer
        }
      end

      def close
        flush_thread = nil
        @mon.synchronize {
          @closed = true
          flush_thread = @flush_thread
          if flush_thread
            @flush_thread = nil
            # make the flush thread awake
            @cv.signal
          end
        }
        flush_thread.join if flush_thread
      end

      private

      attr :max_payload_size
      attr :max_pool_size

      attr :overflowing_stategy
      attr_reader :flush_interval

      attr :connection
      attr :buffer

      def should_flush?(message_size)
        return true if buffer.bytesize + 1 + message_size >= max_payload_size

        false
      end

      def clear_buffer
        buffer.clear
        @message_count = 0
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

      def create_flush_thread
        flush_thread = Thread.new(&method(:flush_loop))
        flush_thread.name = 'Statsd MessageBuffer' unless Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3')
        flush_thread
      end

      def flush_loop
        last_flush_time = current_time
        @mon.synchronize do
          until @closed
            @cv.wait(flush_interval - (current_time - last_flush_time))
            last_flush_time = current_time
            flush
          end
        end
      end

      if Process.const_defined?(:CLOCK_MONOTONIC)
        def current_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      else
        def current_time
          Time.now
        end
      end
    end
  end
end
