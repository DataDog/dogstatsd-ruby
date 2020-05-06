require 'spec_helper'

describe Datadog::Statsd::UDSConnection do
  subject do
    described_class.new(socket_path, logger: logger, telemetry: telemetry)
  end

  let(:socket_path) do
    '/tmp/socket'
  end

  let(:logger) do
    Logger.new(log).tap do |logger|
      logger.level = Logger::DEBUG
    end
  end
  let(:log) { StringIO.new }

  let(:telemetry) do
    instance_double(Datadog::Statsd::Telemetry)
  end

  before do
    allow(Socket)
      .to receive(:new)
      .and_return(uds_socket)
  end

  let(:uds_socket) do
    instance_double(Socket, connect: true, sendmsg_nonblock: true)
  end

  describe '#initialize' do
    it 'uses the provided socket_path' do
      expect(subject.socket_path).to eq '/tmp/socket'
    end
  end

  describe '#write' do
    let(:telemetry) do
      instance_double(Datadog::Statsd::Telemetry, flush?: false, sent: true, dropped: true)
    end

    it 'builds the socket in the right mode' do
      expect(Socket)
        .to receive(:new)
        .once
        .with(Socket::AF_UNIX, Socket::SOCK_DGRAM)

      subject.write('test')
    end

    it 'connects the socket to the right path' do
      expect(uds_socket)
        .to receive(:connect)
        .with(Socket.pack_sockaddr_un('/tmp/socket'))

      subject.write('test')
    end

    it 'sends using the socket' do
      expect(uds_socket)
        .to receive(:sendmsg_nonblock)
        .with('test')

      subject.write('test')
    end

    it 'updates the "sent" telemetry counts' do
      expect(telemetry)
        .to receive(:sent)
        .with(bytes: 4, packets: 1)

      subject.write('test')
    end

    it 'logs the sent message in debug mode' do
      subject.write('test')

      expect(log.string).to match /DEBUG -- : Statsd: test/
    end

    context 'when writing fails' do
      before do
        allow(Socket).to receive(:new).and_return(fake_socket, fake_socket_retry)
      end

      let(:fake_socket) do
        instance_double(Socket,
          connect: true,
          sendmsg_nonblock: true
        )
      end

      let(:fake_socket_retry) do
        instance_double(Socket,
          connect: true,
          sendmsg_nonblock: true
        )
      end

      context 'when having connection resets (retry strategy)'do
        before do
          allow(fake_socket)
            .to receive(:sendmsg_nonblock)
            .and_raise(Errno::ECONNRESET)
        end

        context 'when retrying is working' do
          it 'tries with the initial socket' do
            expect(fake_socket)
              .to receive(:sendmsg_nonblock)
              .with('foobar')

            subject.write('foobar')
          end

          it 'retries on the second opened socket' # do
          #   expect(fake_socket_retry)
          #     .to receive(:sendmsg_nonblock)
          #     .with('foobar')

          #   subject.write('foobar')
          # end

          # FIXME: BadSocketError is not correctly caught by Connection class to retry
          it 'does not correctly retry (1)' do
            expect(Socket)
              .to receive(:new)
              .once

            subject.write('foobar')
          end

          it 'does not correctly retry (2)' do
            subject.write('foobar')

            expect(log.string).to match 'Statsd: Datadog::Statsd::UDSConnection::BadSocketError Errno::ECONNRESET: Connection reset by peer'
          end

          it 'updates the "dropped" telemetry counts' do
            expect(telemetry)
              .to receive(:dropped)
              .with(bytes: 4, packets: 1)

            subject.write('test')
          end
        end

        context 'when retrying fails' do
          context 'because of an unknown error' do
            before do
              allow(fake_socket_retry)
                .to receive(:sendmsg_nonblock)
                .and_raise(RuntimeError, 'yolo')
            end

            it 'ignores the connection failure' do
              expect do
                subject.write('foobar')
              end.not_to raise_error
            end

            # the mecanism to retry is broken, once it's fixed, this test should pass
            it 'logs the error message', pending: true do
              subject.write('foobar')
              expect(log.string).to match 'Statsd: RuntimeError yolo'
            end

            it 'updates the "dropped" telemetry counts' do
              expect(telemetry)
                .to receive(:dropped)
                .with(bytes: 4, packets: 1)

              subject.write('test')
            end
          end

          context 'because of a SocketError' do
            before do
              allow(fake_socket_retry)
                .to receive(:sendmsg_nonblock)
                .and_raise(SocketError, 'yolo')
            end

            it 'ignores the connection failure' do
              expect do
                subject.write('foobar')
              end.not_to raise_error
            end

            # the mecanism to retry is broken, once it's fixed, this test should pass
            it 'logs the error message', pending: true do
              subject.write('foobar')
              expect(log.string).to match 'Statsd: SocketError yolo'
            end

            it 'updates the "dropped" telemetry counts' do
              expect(telemetry)
                .to receive(:dropped)
                .with(bytes: 4, packets: 1)

              subject.write('test')
            end
          end
        end
      end

      context 'when having connection refused (retry strategy)' do
        before do
          allow(fake_socket)
            .to receive(:sendmsg_nonblock)
            .and_raise(Errno::ECONNREFUSED.new('closed stream'))
        end

        context 'when retrying is working' do
          it 'tries with the initial socket' do
            expect(fake_socket)
              .to receive(:sendmsg_nonblock)
              .with('foobar')

            subject.write('foobar')
          end

          it 'retries on the second opened socket' # do
          #   expect(fake_socket_retry)
          #     .to receive(:sendmsg_nonblock)
          #     .with('foobar')

          #   subject.write('foobar')
          # end

          # FIXME: BadSocketError is not correctly caught by Connection class to retry
          it 'does not correctly retry (1)' do
            expect(fake_socket_retry)
              .not_to receive(:sendmsg_nonblock)

            subject.write('foobar')
          end

          it 'does not correctly retry (2)' do
            subject.write('foobar')

            expect(log.string).to match 'Statsd: Datadog::Statsd::UDSConnection::BadSocketError Errno::ECONNREFUSED: Connection refused - closed stream'
          end

          it 'updates the "dropped" telemetry counts' do
            expect(telemetry)
              .to receive(:dropped)
              .with(bytes: 4, packets: 1)

            subject.write('test')
          end
        end

        context 'when retrying fails' do
          context 'because of an unknown error' do
            before do
              allow(fake_socket_retry)
                .to receive(:sendmsg_nonblock)
                .and_raise(RuntimeError, 'yolo')
            end

            it 'ignores the connection failure' do
              expect do
                subject.write('foobar')
              end.not_to raise_error
            end

            # the mecanism to retry is broken, once it's fixed, this test should pass
            it 'logs the error message', pending: true do
              subject.write('foobar')
              expect(log.string).to match 'Statsd: RuntimeError yolo'
            end

            it 'updates the "dropped" telemetry counts' do
              expect(telemetry)
                .to receive(:dropped)
                .with(bytes: 4, packets: 1)

              subject.write('test')
            end
          end

          context 'because of connection still refused' do
            before do
              allow(fake_socket_retry)
                .to receive(:sendmsg_nonblock)
                .and_raise(Errno::ECONNREFUSED, 'yolo')
            end

            it 'ignores the connection failure' do
              expect do
                subject.write('foobar')
              end.not_to raise_error
            end

            # the mecanism to retry is broken, once it's fixed, this test should pass
            it 'logs the error message', pending: true do
              subject.write('foobar')
              expect(log.string).to match 'Errno::ECONNREFUSED Connection refused - yolo'
            end

            it 'updates the "dropped" telemetry counts' do
              expect(telemetry)
                .to receive(:dropped)
                .with(bytes: 4, packets: 1)

              subject.write('test')
            end
          end
        end
      end

      context 'when there is no socket (drop strategy)' do
        before do
          allow(fake_socket)
            .to receive(:sendmsg_nonblock)
            .and_raise(Errno::ENOENT)
        end

        it 'sends using the first socket' do
          expect(fake_socket)
            .to receive(:sendmsg_nonblock)
            .with('foobar')

          subject.write('foobar')
        end

        it 'ignores the writing failure (message dropped)' do
          expect do
            subject.write('foobar')
          end.not_to raise_error
        end

        it 'does not retry to send message' do
          expect(fake_socket_retry)
            .not_to receive(:sendmsg_nonblock)

          subject.write('foobar')
        end

        # TODO: FIXME: we got to exclude the Errno::ENOENT for the retry strategy
        it 'logs the error message', pending: true do
          subject.write('foobar')

          expect(log.string).to match 'Statsd: Errno::ENOENT No such file or directory'
        end

        it 'updates the "dropped" telemetry counts' do
          expect(telemetry)
            .to receive(:dropped)
            .with(bytes: 4, packets: 1)

          subject.write('test')
        end
      end

      context 'when the socket is full (drop strategy)' do
        before do
          skip if RUBY_VERSION < '2.3.0'
        end

        before do
          allow(fake_socket)
            .to receive(:sendmsg_nonblock)
            .and_raise(IO::EAGAINWaitWritable)
        end

        it 'sends using the first socket' do
          expect(fake_socket)
            .to receive(:sendmsg_nonblock)
            .with('foobar')

          subject.write('foobar')
        end

        it 'ignores the writing failure (message dropped)' do
          expect do
            subject.write('foobar')
          end.not_to raise_error
        end

        it 'does not retry to send message' do
          expect(fake_socket_retry)
            .not_to receive(:sendmsg_nonblock)

          subject.write('foobar')
        end

        it 'logs the error message' do
          subject.write('foobar')

          expect(log.string).to match 'Statsd: IO::EAGAINWaitWritable Resource temporarily unavailable'
        end

        it 'updates the "dropped" telemetry counts' do
          expect(telemetry)
            .to receive(:dropped)
            .with(bytes: 4, packets: 1)

          subject.write('test')
        end
      end
    end
  end
end
