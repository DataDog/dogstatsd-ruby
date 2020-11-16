require 'spec_helper'

describe Datadog::Statsd::Sender do
  subject do
    described_class.new(message_buffer)
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
