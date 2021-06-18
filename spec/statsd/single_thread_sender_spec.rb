require 'spec_helper'

describe Datadog::Statsd::SingleThreadSender do
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

    it 'is not starting any thread' do
      expect do
        subject.start
      end.to change { Thread.list.size }.by(0)
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
