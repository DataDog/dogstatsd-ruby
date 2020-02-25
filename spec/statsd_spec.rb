require 'spec_helper'

describe Datadog::Statsd do
  let(:socket) { FakeUDPSocket.new }

  subject do
    described_class.new('localhost', 1234,
      namespace: namespace,
      sample_rate: sample_rate,
      tags: tags,
      telemetry_flush_interval: -1,
    )
  end

  let(:namespace) { 'sample_ns' }
  let(:sample_rate) { nil }
  let(:tags) { %w[abc def] }

  before do
    allow(Socket).to receive(:new).and_return(socket)
    allow(UDPSocket).to receive(:new).and_return(socket)
  end

  describe '#initialize' do
    context 'when using provided values' do
      it 'sets the host correctly' do
        expect(subject.connection.host).to eq 'localhost'
      end

      it 'sets the port correctly' do
        expect(subject.connection.port).to eq 1234
      end

      it 'sets the namespace' do
        expect(subject.namespace).to eq 'sample_ns'
      end

      it 'sets the right tags' do
        expect(subject.tags).to eq %w[abc def]
      end

      context 'when using tags in a hash' do
        let(:tags) do
          {
            one: 'one',
            two: 'two',
          }
        end

        it 'sets the right tags' do
          expect(subject.tags).to eq %w[one:one two:two]
        end
      end
    end

    context 'when using environment variables' do
      subject do
        described_class.new(
          namespace: namespace,
          sample_rate: sample_rate,
          tags: %w[abc def]
        )
      end

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('DD_AGENT_HOST', anything).and_return('myhost')
        allow(ENV).to receive(:fetch).with('DD_DOGSTATSD_PORT', anything).and_return(4321)
        allow(ENV).to receive(:fetch).with('DD_ENTITY_ID', anything).and_return('04652bb7-19b7-11e9-9cc6-42010a9c016d')
      end

      it 'sets the host using the env var DD_AGENT_HOST' do
        expect(subject.connection.host).to eq 'myhost'
      end

      it 'sets the port using the env var DD_DOGSTATSD_PORT' do
        expect(subject.connection.port).to eq 4321
      end

      it 'sets the entity tag using ' do
        expect(subject.tags).to eq [
          'abc',
          'def',
          'dd.internal.entity_id:04652bb7-19b7-11e9-9cc6-42010a9c016d'
        ]
      end
    end

    context 'when using default values' do
      subject do
        described_class.new
      end

      it 'sets the host to default values' do
        expect(subject.connection.host).to eq '127.0.0.1'
      end

      it 'sets the port to default values' do
        expect(subject.connection.port).to eq 8125
      end

      it 'sets no namespace' do
        expect(subject.namespace).to be_nil
      end

      it 'sets no tags' do
        expect(subject.tags).to be_empty
      end
    end

    context 'when testing connection type' do
      let(:fake_socket) do
        FakeUDPSocket.new
      end

      context 'when using a host and a port' do
        before do
          allow(UDPSocket).to receive(:new).and_return(fake_socket)
        end

        it 'uses an UDP socket' do
          expect(subject.connection.send(:socket)).to be fake_socket
        end
      end

      context 'when using a socket_path' do
        subject do
          described_class.new(
            namespace: namespace,
            sample_rate: sample_rate,
            socket_path: '/tmp/socket'
          )
        end

        before do
          allow(Socket).to receive(:new).and_call_original
        end

        it 'uses an UDS socket' do
          expect do
            subject.connection.send(:socket)
          end.to raise_error(Errno::ENOENT, /No such file or directory - connect\(2\)/)
        end
      end
    end
  end
end