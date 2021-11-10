require 'spec_helper'

describe Datadog::Statsd::ConnectionCfg do
  subject do
    described_class.new(host: host, port: port, socket_path: socket_path)
  end

  around do |example|
    ClimateControl.modify(
      'DD_AGENT_HOST' => dd_agent_host,
      'DD_DOGSTATSD_PORT' => dd_dogstatsd_port,
      'DD_DOGSTATSD_SOCKET' => dd_dogstatsd_socket,
    ) do
      example.run
    end
  end

  let(:host) { nil }
  let(:port) { nil }
  let(:socket_path) { nil }
  let(:dd_agent_host) { nil }
  let(:dd_dogstatsd_port) { nil }
  let(:dd_dogstatsd_socket) { nil }

  describe '#initialize' do
    context 'with host/port args and env vars set' do
      let(:host) { 'my-agent' }
      let(:port) { 1234 }
      let(:dd_agent_host) { 'unused' }
      let(:dd_dogstatsd_port) { '999' }
      let(:dd_dogstatsd_socket) { '/un/used' }

      it 'creates a UDP connection' do
        expect(subject.transport_type).to eq :udp
      end

      it 'uses the agent name from the args' do
        expect(subject.host).to eq 'my-agent'
      end

      it 'uses the port name from the args' do
        expect(subject.port).to eq 1234
      end

      it 'sets socket_path to nil' do
        expect(subject.socket_path).to eq nil
      end
    end

    context 'with both host/port and socket args' do
      let(:host) { 'my-agent' }
      let(:port) { 1234 }
      let(:socket_path) { '/some/socket' }

      it 'raises an exception' do
        expect do
          subject.new(host: host, port: port, socket_path: socket_path)
        end.to raise_error(
          ArgumentError,
          "Both UDP: (host/port my-agent:1234) and UDS (socket_path /some/socket) constructor arguments were given.  Use only one or the other.")
      end
    end

    context 'with socket_path arg and env vars' do
      let(:socket_path) { '/some/socket' }
      let(:dd_agent_host) { 'unused' }
      let(:dd_dogstatsd_port) { '999' }
      let(:dd_dogstatsd_socket) { '/un/used' }

      it 'creates a UDS connection' do
        expect(subject.transport_type).to eq :uds
      end

      it 'sets host to nil' do
        expect(subject.host).to eq nil
      end

      it 'sets port to nil' do
        expect(subject.port).to eq nil
      end

      it 'sets socket_path to path in the arg' do
        expect(subject.socket_path).to eq '/some/socket'
      end
    end

    context 'with no args and DD_AGENT_HOST set' do
      let(:dd_agent_host) { 'some-host' }

      it 'creates a UDP connection' do
        expect(subject.transport_type).to eq :udp
      end

      it 'sets host to DD_AGENT_HOST' do
        expect(subject.host).to eq 'some-host'
      end

      it 'sets port to 8125 (default)' do
        expect(subject.port).to eq 8125
      end

      it 'sets socket_path to nil' do
        expect(subject.socket_path).to eq nil
      end

      context 'and DD_DOGSTATSD_PORT set' do
        let(:dd_dogstatsd_port) { '1234' }

        it 'creates a UDP connection' do
          expect(subject.transport_type).to eq :udp
        end

        it 'sets host to DD_AGENT_HOST' do
          expect(subject.host).to eq 'some-host'
        end

        it 'sets port to DD_DOGSTATSD_PORT' do
          expect(subject.port).to eq 1234
        end

        it 'sets socket_path to nil' do
          expect(subject.socket_path).to eq nil
        end
      end
    end

    context 'with no args and DD_DOGSTATSD_SOCKET set' do
      let(:dd_dogstatsd_socket) { '/some/socket' }

      it 'creates a UDS connection' do
        expect(subject.transport_type).to eq :uds
      end

      it 'sets host to nil' do
        expect(subject.host).to eq nil
      end

      it 'sets port to nil' do
        expect(subject.port).to eq nil
      end

      it 'sets socket_path to DD_DOGSTATSD_SOCKET' do
        expect(subject.socket_path).to eq '/some/socket'
      end
    end

    context 'with both DD_AGENT_HOST and DD_DOGSTATSD_SOCKET set' do
      let(:dd_agent_host) { 'some-host' }
      let(:dd_dogstatsd_socket) { '/some/socket' }

      it 'raises an exception' do
        expect do
          subject.new(host: host, port: port, socket_path: socket_path)
        end.to raise_error(
          ArgumentError,
          'Both UDP (DD_AGENT_HOST/DD_DOGSTATSD_PORT some-host:) and UDS (DD_DOGSTATSD_SOCKET /some/socket) environment variables are set.  Set only one or the other.')
      end
    end

    context 'with no args and no env vars set' do
      it 'creates a UDP connection' do
        expect(subject.transport_type).to eq :udp
      end

      it 'sets host to 127.0.0.1 (default)' do
        expect(subject.host).to eq '127.0.0.1'
      end

      it 'sets port to 8125 (default)' do
        expect(subject.port).to eq 8125
      end

      it 'sets socket_path to nil' do
        expect(subject.socket_path).to eq nil
      end
    end
  end

  describe '#make_connection' do
    context 'for a UDP connection' do
      before do
        allow(Datadog::Statsd::UDPConnection)
          .to receive(:new)
          .with(host, port, param: 'param')
          .and_return(udp_connection)
      end

      let(:host) { 'my-agent' }
      let(:port) { 1234 }
      let(:udp_connection) do
        instance_double(Datadog::Statsd::UDPConnection)
      end

      it 'creates a UDP connection, passing along params' do
        expect(subject.make_connection(param: 'param')).to eq udp_connection
      end
    end

    context 'for a UDS connection' do
      before do
        allow(Datadog::Statsd::UDSConnection)
          .to receive(:new)
          .with(socket_path, param: 'param')
          .and_return(uds_connection)
      end

      let(:socket_path) { '/tmp/dd-socket' }
      let(:uds_connection) do
        instance_double(Datadog::Statsd::UDSConnection,
          socket_path: socket_path
        )
      end

      it 'creates a UDS connection, passing along params' do
        expect(subject.make_connection(param: 'param')).to eq uds_connection
      end
    end
  end
end
