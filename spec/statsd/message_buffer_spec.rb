require 'spec_helper'

describe Datadog::Statsd::MessageBuffer do
  subject do
    described_class.new(connection,
      max_buffer_payload_size: max_buffer_payload_size,
      max_buffer_pool_size: max_buffer_pool_size
    )
  end

  let(:connection) do
    instance_double(Datadog::Statsd::UDPConnection)
  end

  let(:max_buffer_payload_size) do
    64
  end

  let(:max_buffer_pool_size) do
    3
  end

  describe '#add' do
    context 'when the buffer is empty' do
      context 'when the message is lesser than the max size' do
        it 'does not flush' do
          expect(connection).not_to receive(:write)

          subject.add('a' * 63)
        end
      end

      context 'when the message is bigger than the max size' do
        # this logic has to be reworked
        it 'does not flush' do
          expect(connection).not_to receive(:write)

          subject.add('a' * 65)
        end
      end
    end

    context 'when the buffer already has messages' do
      before do
        subject.add('a')
      end

      context 'when reaching the maximum pool size' do
        before do
          subject.add('a')
        end

        it 'flushes the previous messages' do
          expect(connection)
            .to receive(:write)
            .with("a\na")

          subject.add('a')
        end
      end

      context 'when we get the max size' do
        it 'flushes the previous messages' do
          expect(connection)
            .to receive(:write)
            .with("a")

          subject.add('a' * 62)
        end
      end

      context 'when we overflow the max size' do
        it 'flushes the previous messages' do
          expect(connection)
            .to receive(:write)
            .with("a")

          subject.add('a' * 75)
        end
      end

      context "when the don't overflow the max size" do
        it 'does not flush' do
          expect(connection).not_to receive(:write)

          subject.add('a' * 61)
        end
      end
    end
  end
end
