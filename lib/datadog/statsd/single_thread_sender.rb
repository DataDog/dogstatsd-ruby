# frozen_string_literal: true

module Datadog
  class Statsd
    # The SingleThreadSender is a sender synchronously buffering messages
    # in a `MessageBuffer`.
    # It is using current Process.PID to check it is the result of a recent fork
    # and it is reseting the MessageBuffer if that's the case.
    class SingleThreadSender
      def initialize(message_buffer, logger: nil, flush_interval: nil)
        @message_buffer = message_buffer
        @logger = logger
        @mx = Mutex.new
        @flush_timer = if flush_interval
          Datadog::Statsd::Timer.new(flush_interval) { flush }
        else
          nil
        end
        # store the pid for which this sender has been created
        update_fork_pid
      end

      def add(message)
        @mx.synchronize {
          # we have just forked, meaning we have messages in the buffer that we should
          # not send, they belong to the parent process, let's clear the buffer.
          if forked?
            @message_buffer.reset
            @flush_timer.start if @flush_timer && @flush_timer.stop?
            update_fork_pid
          end
          @message_buffer.add(message)
        }
      end

      def flush(*)
        @mx.synchronize {
          @message_buffer.flush()
        }
      end

      def start()
        @flush_timer.start if @flush_timer
      end

      def stop()
        @flush_timer.stop if @flush_timer
      end

      # Compatibility with `Sender`
      def rendez_vous()
      end

      private

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
