# frozen_string_literal: true

module Datadog
  class Statsd
    class Sender
      def initialize(message_buffer)
        @message_buffer = message_buffer
      end

      def flush(sync: false)
        raise ArgumentError, 'Start sender first' unless message_queue

        message_queue.push(:flush)

        rendez_vous if sync
      end

      def rendez_vous
        # Initialize and get the thread's sync queue
        queue = (Thread.current[:statsd_sync_queue] ||= Queue.new)
        # tell sender-thread to notify us in the current
        # thread's queue
        message_queue.push(queue)
        # wait for the sender thread to send a message
        # once the flush is done
        queue.pop
      end

      def add(message)
        raise ArgumentError, 'Start sender first' unless message_queue

        message_queue << message
      end

      def start
        raise ArgumentError, 'Sender already started' if message_queue

        # initialize message queue for background thread
        @message_queue = Queue.new
        # start background thread
        @sender_thread = Thread.new(&method(:send_loop))
      end

      def stop(join_worker: true)
        message_queue.close if message_queue
        sender_thread.join if sender_thread && join_worker
      end

      private

      attr_reader :message_buffer

      attr_reader :message_queue
      attr_reader :sender_thread

      def send_loop
        until (message = message_queue.pop).nil? && message_queue.closed?
          # skip if message is nil, e.g. when message_queue
          # is empty and closed
          next unless message

          case message
          when :flush
            message_buffer.flush
          when Queue
            message.push(:go_on)
          else
            message_buffer.add(message)
          end
        end

        @message_queue = nil
        @sender_thread = nil
      end
    end
  end
end
