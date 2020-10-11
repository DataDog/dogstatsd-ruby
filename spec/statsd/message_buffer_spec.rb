require 'spec_helper'

describe Datadog::Statsd::MessageBuffer do
  subject do
    described_class.new(connection,
      max_payload_size: max_payload_size,
      max_pool_size: max_pool_size,
      overflowing_stategy: overflowing_stategy,
      flush_interval: flush_interval,
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

  let(:flush_interval) do
    nil
  end

  describe '#initialize' do
    context 'when flush_interval is not set' do
      let(:flush_interval) do
        nil
      end

      it 'does not create the flush thread' do
        expect do
          subject
        end.to change { Thread.list.size }.by(0)
      end
    end

    context 'when flush_interval is set' do
      let(:flush_interval) do
        0.001
      end

      it 'creates the flush thread and flushes the buffer' do
        mutex = Mutex.new
        cv = ConditionVariable.new
        expect do
          subject
        end.to change { Thread.list.size }.by(1)

        expect(subject).to receive(:flush).and_wrap_original do
          mutex.synchronize { cv.broadcast }
        end

        # wait a second or until #flush is called
        mutex.synchronize { cv.wait(mutex, 1) }
      end
    end
  end

  describe '#add' do
    context 'when the message is empty' do
      it 'returns nil' do
        expect(subject.add('')).to be nil
      end

      it 'never flushes (never adds only \n)' do
        expect(connection).not_to receive(:write)

        1000.times { subject.add('') }
      end
    end

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

    context 'after #close is called' do
      it 'raises a specific error' do
        subject.close
        expect do
          subject.add('a')
        end.to raise_error(Datadog::Statsd::Error, 'buffer is closed')
      end
    end
  end

  describe '#close' do
    context 'when flush_interval is not set' do
      let(:flush_interval) do
        nil
      end

      it 'does nothing' do
        expect do
          subject
        end.to change { Thread.list.size }.by(0)
      end
    end

    context 'when flush_interval is set' do
      let(:flush_interval) do
        15
      end

      it 'calls #flush immediately and deletes the flush thread' do
        expect(subject).to receive(:flush)

        # sleep a little for the flush thread to call ConditionVariable#wait
        sleep 0.001

        # call #flush without waiting flush_interval
        Timeout.timeout(1) do
          expect { subject.close }.to change { Thread.list.size }.by(-1)
        end
      end
    end
  end
end
