# frozen_string_literal: true

module Datadog
  class FlushQueue < Queue
  end
  class CloseQueue < Queue
  end
  class Statsd
    # Sender is using a background thread to flush and pack messages
    # in a `MessageBuffer`.
    # The communication with this thread is done using a `Queue`.
    # If the thread is dead, it is starting a new one to avoid having a blocked
    # Sender with no background thread to communicate with (most of the time,
    # having a dead background thread means that a fork just happened and that we
    # are running in the child process).
    class Sender
      CLOSEABLE_QUEUES = Queue.instance_methods.include?(:close)

      def initialize(message_buffer, logger: nil)
        @message_buffer = message_buffer
        @logger = logger

        # communication and synchronization with the background thread
        # @mux is also used to not having multiple threads fighting for
        # closing the Sender or creating a new background thread
        @channel = Queue.new
        @mux = Mutex.new

        @is_closed = false

        # start background thread immediately
        @sender_thread = Thread.new(&method(:send_loop))
      end

      def flush(sync: false)
        @mux.synchronize {
          # we don't want to send a flush action to the bg thread if:
          # - there is no bg thread running
          # - the sender has been closed
          return if !sender_thread.alive? || @is_closed

          if sync
             # blocking flush
             blocking_queue = FlushQueue.new
             channel << blocking_queue
             blocking_queue.pop # wait for the bg thread to finish its work
             blocking_queue.close if CLOSEABLE_QUEUES
           else
             # asynchronous flush
             channel << :flush
           end
         }
      end

      def add(message)
        return if @is_closed # don't send a message to the bg thread if the sender has been closed

        # the bg thread is not running anymore, this is happening if the main process has forked and
        # we are running in the child, we will spawn a bg thread and reset buffers (containing parents' messages)
        if !sender_thread.alive?
          @mux.synchronize {
            return if @is_closed
            # test if a call from another thread has already re-created
            # the background thread before this one acquired the lock
            break if sender_thread.alive?

            # re-create the channel of communication since we will spawn a new bg thread
            channel.close if CLOSEABLE_QUEUES
            @channel = Queue.new
            message_buffer.reset # don't use messages appended by another fork
            @sender_thread = Thread.new(&method(:send_loop))
          }
        end

        channel << message
      end

      # Compatibility with `Sender`
      def start()
      end

      def stop()
        return if @is_closed
        # use this lock to both: not having another thread stopping this instance nor
        # having a #add call creating a new thread
        @mux.synchronize {
          @is_closed = true
          if sender_thread.alive? # no reasons to stop the bg thread is none is running already
            blocking_queue = CloseQueue.new
            channel << blocking_queue
            blocking_queue.pop # wait for the bg thread to finish its work
            blocking_queue.close if CLOSEABLE_QUEUES
            sender_thread.join(3) # wait for completion, timeout after 3 seconds
            # TODO(remy): should I close `channel` here?
          end
        }
      end

      private

      attr_reader :message_buffer
      attr_reader :channel
      attr_reader :mux
      attr_reader :sender_thread

      def send_loop
        until (message = channel.pop).nil? && (CLOSEABLE_QUEUES && channel.closed?)
          # skip if message is nil, e.g. when the channel is empty and closed
          next unless message

          case message
          # if a FlushQueue is received, the background thread has to flush the message
          # buffer and to send an :unblock to let the caller know that it has finished
          when FlushQueue
            message_buffer.flush
            message << :unblock
          # if a :flush is received, the background thread has to flush asynchronously
          when :flush
            message_buffer.flush
          # if a CloseQueue is received, the background thread has to do a last flush
          # and to send an :unblock to let the caller know that it has finished
          when CloseQueue
            message << :unblock
            return
          else
            message_buffer.add(message)
          end
        end
      end
    end
  end
end
