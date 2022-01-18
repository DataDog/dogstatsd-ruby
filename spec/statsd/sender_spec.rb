require 'spec_helper'

describe Datadog::Statsd::Sender do
  subject do
    described_class.new(message_buffer, flush_interval: flush_interval)
  end

  let(:message_buffer) do
    instance_double(Datadog::Statsd::MessageBuffer)
  end
  let(:flush_interval) { nil }

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

    context 'when starting and stopping' do
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
