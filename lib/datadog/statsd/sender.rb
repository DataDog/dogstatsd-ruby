# frozen_string_literal: true

module Datadog
  class Statsd
    # Sender is using a companion thread to flush and pack messages
    # in a `MessageBuffer`.
    # The communication with this thread is done using a `Queue`.
    # If the thread is dead, it is starting a new one to avoid having a blocked
    # Sender with no companion thread to communicate with (most of the time, having
    # a dead companion thread means that a fork just happened and that we are
    # running in the child process).
    class Sender
      CLOSEABLE_QUEUES = Queue.instance_methods.include?(:close)

      def initialize(message_buffer)
        @message_buffer = message_buffer
      end

      def flush(sync: false)
        # don't try to flush if there is no message_queue instantiated
        return unless message_queue

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

        # if the thread does not exist, we are probably running in a forked process,
        # empty the message queue (these messages belong to parent process) and spawn
        # a new companion thread.
        if !sender_thread.alive?
          @message_queue = nil
          start
        end

        message_queue << message
      end

      def start
        raise ArgumentError, 'Sender already started' if message_queue

        # initialize message queue for background thread
        @message_queue = Queue.new
        # start background thread
        @sender_thread = Thread.new(&method(:send_loop))
      end

      if CLOSEABLE_QUEUES
        def stop(join_worker: true)
          message_queue = @message_queue
          message_queue.close if message_queue

          sender_thread = @sender_thread
          sender_thread.join if sender_thread && join_worker
        end
      else
        def stop(join_worker: true)
          message_queue = @message_queue
          message_queue << :close if message_queue

          sender_thread = @sender_thread
          sender_thread.join if sender_thread && join_worker
        end
      end

      private

      attr_reader :message_buffer
      attr_reader :message_queue
      attr_reader :sender_thread

      if CLOSEABLE_QUEUES
        def send_loop
          until !Thread.current.alive? || ((message = message_queue.pop).nil? && message_queue.closed?)
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
      else
        def send_loop
          loop do
            message = message_queue.pop

            next unless message

            case message
            when :close
              break
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
end
