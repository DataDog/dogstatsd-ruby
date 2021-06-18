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

      def flush(*)
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
