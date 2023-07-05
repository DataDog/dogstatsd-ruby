require 'spec_helper'

describe Datadog::Statsd::SingleThreadSender do
  subject do
    described_class.new(message_buffer, flush_interval: flush_interval, queue_size: queue_size)
  end

  let(:message_buffer) do
    instance_double(Datadog::Statsd::MessageBuffer)
  end
  let(:flush_interval) { nil }
  let(:queue_size) { 6 }

  describe '#start' do
    after do
      subject.stop
    end

    it 'is not starting any thread' do
      expect do
        subject.start
      end.to change { Thread.list.size }.by(0)
    end

    context 'when flush_interval is set' do
      let(:flush_interval) { 0.001 }

      it 'starts flush timer thread' do
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
        end.to change { Thread.list.size }.by(1)

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

    context 'when flush_interval is set' do
      let(:flush_interval) { 15 }

      it 'stops the flush timer thread' do
        allow(subject).to receive(:flush)
        expect do
          subject.stop
        end.to change { Thread.list.size }.by(-1)
      end
    end
  end

  describe '#add' do
    context 'when starting and stopping' do
      before do
        subject.start
      end

      after do
        subject.stop
      end

      context 'when number of messages < queue size' do
        it 'does not touch the message buffer' do
          n = queue_size - 1
          n.times do |i|
            subject.add("sample message #{i}")
          end
        end
      end

      context 'when number of messages == queue size' do
        it 'adds queued messages to the message buffer' do
          n = queue_size

          n.times do |i|
            expect(message_buffer)
              .to receive(:add)
              .with("sample message #{i}")
              .ordered
          end
          expect(message_buffer).to receive(:add).exactly(0).times

          n.times do |i|
            subject.add("sample message #{i}")
          end
        end
      end
    end
  end

  describe '#flush' do
    context 'when starting and stopping' do
      before do
        subject.start
      end

      after do
        subject.stop
      end

      it 'adds queued messages to the message buffer and flushes it' do
        n = queue_size - 1

        n.times do |i|
          expect(message_buffer)
            .to receive(:add)
            .with("sample message #{i}")
            .ordered
        end
        # and then expect no more adds!
        expect(message_buffer).to receive(:add).exactly(0).times
        expect(message_buffer)
          .to receive(:flush)

        n.times do |i|
          subject.add("sample message #{i}")
        end
        subject.flush
      end
    end
  end
end
