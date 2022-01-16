require 'spec_helper'

describe Datadog::Statsd::SingleThreadSender do
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
        expect(subject).to receive(:flush).and_wrap_original do
          mutex.synchronize { cv.broadcast }
        end

        expect do
          subject.start
        end.to change { Thread.list.size }.by(1)

        # wait a second or until #flush is called
        mutex.synchronize { cv.wait(mutex, 1) }

        # subject.stop calls #flush
        allow(subject).to receive(:flush)
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

      it 'adds a message to the message buffer asynchronously (needs rendez_vous)' do
        expect(message_buffer)
          .to receive(:add)
          .with('sample message')

        subject.add('sample message')
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

      it 'flushes the message buffer' do
        expect(message_buffer)
          .to receive(:flush)

        subject.flush
      end
    end
  end
end
