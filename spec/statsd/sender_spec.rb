require 'spec_helper'

describe Datadog::Statsd::Sender do
  subject do
    described_class.new(
      message_buffer,
      flush_interval: flush_interval,
      telemetry: telemetry,
      queue_size: queue_size,
      queue_class: queue_class,
      thread_class: thread_class)
  end

  let(:queue_size) { 5 }
  let(:queue_class) { Queue }
  let(:thread_class) { Thread }

  let(:message_buffer) do
    instance_double(Datadog::Statsd::MessageBuffer)
  end
  let(:flush_interval) { nil }

  let(:telemetry) do
    instance_double(Datadog::Statsd::Telemetry)
  end

  describe '#start' do
    after do
      subject.stop
    end

    it 'starts a worker thread' do
      expect do
        subject.start
      end.to change { Thread.list.size }.by(1)
    end

    context 'on Ruby >= 2.3' do
      before do
        if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3')
          skip 'Thread names not supported on old Rubies'
        end
      end

      it 'names the sender thread' do
        subject.start
        expect(Thread.list).to satisfy {
          |thds| thds.any? { |t| t.name == "Statsd Sender" }
        }
      end
    end

    context 'when the sender is started' do
      before do
        subject.start
      end

      it 'raises an ArgumentError' do
        expect do
          subject.start
        end.to raise_error(ArgumentError, /Sender already started/)
      end
    end

    context 'when a ThreadError is raised starting the sender thread' do
      let(:thread_class) do
        class_double(Thread)
      end

      before do
        allow(thread_class).to receive(:new).and_raise(ThreadError, "ThreadError")
      end

      it 'ignores the thread error' do
        expect do
          subject.start
        end.not_to raise_error
      end
    end

    context 'when flush_interval is set' do
      let(:flush_interval) { 0.001 }

      it 'starts a worker thread and a flush timer thread' do
        mutex = Mutex.new
        cv = ConditionVariable.new
        flush_called = false

        # #flush can be called multiple times before #stop is called.
        # It is also called in #stop, which is executed in the after callback,
        # so "expect(subject).to receive(:flush).at_least(:once)" doesn't work.
        allow(subject).to receive(:flush) do
          mutex.synchronize do
            flush_called = true
            cv.broadcast
          end
        end

        expect do
          subject.start
        end.to change { Thread.list.size }.by(2)

        # wait a second or until #flush is called
        mutex.synchronize do
          cv.wait(mutex, 1) unless flush_called
        end

        expect(flush_called).to be true
      end
    end
  end

  describe '#stop' do
    before do
      subject.start
    end

    context 'when flush_interval is not set' do
      it 'stops the worker thread' do
        expect do
          subject.stop
        end.to change { Thread.list.size }.by(-1)
      end
    end

    context 'when flush_interval is set' do
      let(:flush_interval) { 15 }

      it 'stops the worker thread and the flush timer thread' do
        # sleep a little to wait for the sender thread to start
        sleep 0.01

        expect(message_buffer).to receive(:flush)
        expect do
          subject.stop
        end.to change { Thread.list.size }.by(-2)
      end
    end
  end

  describe '#add' do
    context 'when the sender is not started' do
      it 'raises an ArgumentError' do
        expect do
          subject.add('sample message')
        end.to raise_error(ArgumentError, /Start sender first/)
      end
    end

    context 'when started' do
      before do
        subject.start
      end

      after do
        subject.stop
      end

      it 'adds a message to the message buffer asynchronously (needs rendez_vous)' do
        expect(message_buffer)
          .to receive(:add)
          .with('sample message')

        subject.add('sample message')

        subject.rendez_vous
      end

      context 'with fake queue and fake sender thread' do
        let(:fake_queue) do
          if Queue.instance_methods.include?(:close)
            instance_double(Queue, { "length" => fake_queue_length, "<<" => true, "close" => true })
          else
            instance_double(Queue, { "length" => fake_queue_length, "<<" => true })
          end
        end

        let(:queue_class) do
          class_double(Queue, new: fake_queue)
        end

        let(:thread_class) do
          if Thread.instance_methods.include?(:name=)
            fake_thread = instance_double(Thread, { "alive?" => true, "name=" => true, "join" => true })
          else
            fake_thread = instance_double(Thread, { "alive?" => true, "join" => true })
          end
          class_double(Thread, new: fake_thread)
        end

        context 'with fewer messages in queue than queue_size' do
          let(:fake_queue_length) { queue_size }

          it 'adds only messages up to queue_size messages' do
            expect(fake_queue).to receive(:<<).with('message')
            if not Queue.instance_methods.include?(:close)
              expect(fake_queue).to receive(:<<).with(:close)
            end
            expect(telemetry).not_to receive(:dropped_queue)
            subject.add('message')
          end
        end

        context 'with more messages in queue than queue_size' do
          let(:fake_queue_length) { queue_size + 1 }

          it 'adds only messages up to queue_size messages' do
            if Queue.instance_methods.include?(:close)
              expect(fake_queue).not_to receive(:<<)
            else
              expect(fake_queue).to receive(:<<).with(:close)
            end
            expect(telemetry).to receive(:dropped_queue).with(bytes: 7, packets: 1)
            subject.add('message')
          end
        end
      end
    end
  end

  describe '#flush' do
    context 'when the sender is not started' do
      it 'raises an ArgumentError' do
        expect do
          subject.add('sample message')
        end.to raise_error(ArgumentError, /Start sender first/)
      end
    end

    context 'when starting and stopping' do
      before do
        subject.start
      end

      after do
        subject.stop
      end

      context 'without sync mode' do
        it 'flushes the message buffer (needs rendez_vous)' do
          expect(message_buffer)
            .to receive(:flush)

          subject.flush
          subject.rendez_vous
        end
      end

      context 'with sync mode' do
        it 'flushes the message buffer and waits (no explicit rendez_vous)' do
          expect(message_buffer)
            .to receive(:flush)

          subject.flush(sync: true)
        end
      end
    end
  end
end
