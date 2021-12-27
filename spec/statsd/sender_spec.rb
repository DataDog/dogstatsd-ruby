require 'spec_helper'

class Waiter
  def initialize()
    @mx = Mutex.new
    @cv = ConditionVariable.new
    @sig = false
  end

  def wait()
    @mx.synchronize { @cv.wait(@mx) until @sig }
  end

  def signal()
    @mx.synchronize {
      @sig = true
      @cv.signal
    }
  end
end

describe Datadog::Statsd::Sender do
  subject do
    described_class.new(message_buffer, queue_size: 5)
  end

  let(:message_buffer) do
    instance_double(Datadog::Statsd::MessageBuffer)
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
  end

  describe '#stop' do
    before do
      subject.start
    end

    it 'stops the worker thread' do
      expect do
        subject.stop
      end.to change { Thread.list.size }.by(-1)
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

      it 'adds only messages up to queue_size messages' do
        # keep the sender thread busy handling a flush
        waiter = Waiter.new
        expect(message_buffer)
          .to receive(:flush) { waiter.wait }
        subject.flush

        # send six messages; sixth is dropped
        for i in 0..6 do
          subject.add('message')
        end

        expect(message_buffer)
          .to receive(:add)
          .with('message')
          .exactly(5).times

        # resume the sender thread again to receive those six
        # messages
        waiter.signal

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
