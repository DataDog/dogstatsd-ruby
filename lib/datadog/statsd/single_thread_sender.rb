# frozen_string_literal: true

module Datadog
  class Statsd
    class SingleThreadSender
      def initialize(message_buffer)
        @message_buffer = message_buffer
      end

      def add(message)
        @message_buffer.add(message)
      end

      # We do not use the `sync` parameter since the `SingleThreadSender` is always
      # synchronous. However, we still have it to have the same method signature
      # with `Sender`.
      def flush(sync: true)
        @message_buffer.flush()
      end

      # Compatibility with `Sender`
      def start()
      end

      # Compatibility with `Sender`
      def stop()
      end

      # Compatibility with `Sender`
      def rendez_vous()
      end
    end
  end
end
