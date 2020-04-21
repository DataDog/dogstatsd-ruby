require 'spec_helper'

describe Datadog::Statsd::MessageBuffer do
  subject do
    described_class.new(connection,
      max_buffer_payload_size: max_buffer_payload_size,
      max_buffer_pool_size: max_buffer_pool_size,
      buffer_overflowing_stategy: buffer_overflowing_stategy,
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

  let(:buffer_overflowing_stategy) do
    :drop
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
        context 'in buffer overflow mode :drop' do
          it 'does not flush' do
            expect(connection).not_to receive(:write)

            subject.add('a' * 65)
          end
        end

        context 'in buffer overflow mode :raise' do
          let(:buffer_overflowing_stategy) do
            :raise
          end

          it 'raises a specific error' do
            expect do
              subject.add('a' * 65)
            end.to raise_error(Datadog::Statsd::Error, 'Message too big for payload limit')
          end
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
        context 'in buffer overflow mode :drop' do
          it 'does not flush' do
            expect(connection).not_to receive(:write)

            subject.add('a' * 75)
          end
        end

        context 'in buffer overflow mode :raise' do
          let(:buffer_overflowing_stategy) do
            :raise
          end

          it 'raises a specific error' do
            expect do
              subject.add('a' * 75)
            end.to raise_error(Datadog::Statsd::Error, 'Message too big for payload limit')
          end
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
