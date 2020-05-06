require 'spec_helper'

describe Datadog::Statsd::MessageBuffer do
  subject do
    described_class.new(connection,
      max_payload_size: max_payload_size,
      max_pool_size: max_pool_size,
      overflowing_stategy: overflowing_stategy,
    )
  end

  let(:connection) do
    instance_double(Datadog::Statsd::UDPConnection)
  end

  let(:max_payload_size) do
    100
  end

  let(:max_pool_size) do
    3
  end

  let(:overflowing_stategy) do
    :drop
  end

  describe '#add' do
    context 'when the buffer is empty' do
      context 'when the message is lesser than the max size - send tolerance' do
        it 'does not flush' do
          expect(connection).not_to receive(:write)

          subject.add('a' * 95)
        end
      end

      context 'when the message is equal to the max size (- tolerance)' do
        it 'flushes the message' do
          expect(connection)
            .to receive(:write)
            .with('a' * 96)

          subject.add('a' * 96)
        end
      end

      context 'when the message is equal to the max size (- tolerance)' do
        it 'flushes the message' do
          expect(connection)
            .to receive(:write)
            .with('a' * 100)

          subject.add('a' * 100)
        end
      end

      context 'when the message is bigger than the max size' do
        context 'in buffer overflow mode :drop' do
          it 'does not flush' do
            expect(connection).not_to receive(:write)

            subject.add('a' * 101)
          end
        end

        context 'in buffer overflow mode :raise' do
          let(:overflowing_stategy) do
            :raise
          end

          it 'raises a specific error' do
            expect do
              subject.add('a' * 101)
            end.to raise_error(Datadog::Statsd::Error, 'Message too big for payload limit')
          end
        end
      end
    end

    context 'when the buffer already has messages' do
      before do
        subject.add('aaaaaa')
      end

      context 'when reaching the maximum pool size' do
        before do
          subject.add('a')
        end

        it 'flushes the messages' do
          expect(connection)
            .to receive(:write)
            .with("aaaaaa\na\na")

          subject.add('a')
        end
      end

      context 'when we get the max size' do
        it 'flushes the previous messages as there is not enough space to bufferize new message' do
          expect(connection)
            .to receive(:write)
            .with("aaaaaa")

          subject.add('a' * 94)
        end
      end

      context 'when we overflow the max size' do
        context 'in buffer overflow mode :drop' do
          it 'does not flush' do
            expect(connection).not_to receive(:write)

            subject.add('a' * 105)
          end
        end

        context 'in buffer overflow mode :raise' do
          let(:overflowing_stategy) do
            :raise
          end

          it 'raises a specific error' do
            expect do
              subject.add('a' * 105)
            end.to raise_error(Datadog::Statsd::Error, 'Message too big for payload limit')
          end
        end
      end

      context "when the don't overflow the max size" do
        it 'does not flush' do
          expect(connection).not_to receive(:write)

          subject.add('a' * 20)
        end
      end
    end
  end
end
