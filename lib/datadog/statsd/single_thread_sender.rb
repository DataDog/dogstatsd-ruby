# frozen_string_literal: true

module Datadog
  class Statsd
    class SingleThreadSender
      def initialize(message_buffer)
        @message_buffer = message_buffer
        # store the pid for which this sender has been created
        update_fork_pid
      end

      def add(message)
        # we have just forked, meaning we have messages in the buffer that we should
        # not send, they belong to the parent process, let's clear the buffer.
        if forked?
          @message_buffer.reset
          update_fork_pid
        end
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

      # below are "fork management" methods to be able to clean the MessageBuffer
      # if it detects that it is running in a unknown PID.

      def forked?
        Process.pid != @fork_pid
      end

      def update_fork_pid
        @fork_pid = Process.pid
      end
    end
  end
end
