# frozen_string_literal: true

require 'spec_helper'

describe 'Telemetry integration testing' do
  let(:socket) { FakeUDPSocket.new(copy_message: true) }

  subject do
    Datadog::Statsd.new('localhost', 1234,
      telemetry_flush_interval: -1
    )
  end

  before do
    allow(Socket).to receive(:new).and_return(socket)
    allow(UDPSocket).to receive(:new).and_return(socket)
  end

  let(:namespace) { nil }
  let(:sample_rate) { nil }
  let(:tags) { nil }

  let(:socket) { FakeUDPSocket.new(copy_message: true) }

  context 'when disabling telemetry' do
    subject do
      Datadog::Statsd.new('localhost', 1234,
        telemetry_enable: false,
      )
    end

    it 'does not send any telemetry' do
      subject.count("test", 21)
      subject.flush

      expect(socket.recv[0]).to eq 'test:21|c'
    end

    it 'is disabled' do
      expect(subject.telemetry).to be nil
    end
  end

  it 'is enabled by default' do
    expect(subject.telemetry).not_to be nil
  end

  context 'when flushing only every 2 seconds' do
    before do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 12))
      allow(Process).to receive(:clock_gettime).and_return(0) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
      subject
    end

    after do
      Timecop.return
    end

    subject do
      Datadog::Statsd.new('localhost', 1234,
        telemetry_flush_interval: 2,
      )
    end

    it 'does not send telemetry before the delay' do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 13))
      allow(Process).to receive(:clock_gettime).and_return(1) if Datadog::Statsd::PROCESS_TIME_SUPPORTED

      subject.count('test', 21)

      subject.flush

      expect(socket.recv[0]).to eq 'test:21|c'
    end

    it 'sends telemetry after the delay' do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 15))
      allow(Process).to receive(:clock_gettime).and_return(3) if Datadog::Statsd::PROCESS_TIME_SUPPORTED

      subject.count('test', 21)

      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'test:21|c'
    end
  end

  it 'handles all data type' do
    subject.increment('test', 1)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('test:1|c', metrics: 1, packets_sent: 0, bytes_sent: 0)

    subject.decrement('test', 1)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('test:-1|c', metrics: 1, packets_sent: 1, bytes_sent: 680)

    subject.count('test', 21)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('test:21|c', metrics: 1, packets_sent: 1, bytes_sent: 683)

    subject.gauge('test', 21)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('test:21|g', metrics: 1, packets_sent: 1, bytes_sent: 683)

    subject.histogram('test', 21)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('test:21|h', metrics: 1, packets_sent: 1, bytes_sent: 683)

    subject.timing('test', 21)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('test:21|ms', metrics: 1, packets_sent: 1, bytes_sent: 683)

    subject.set('test', 21)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('test:21|s', metrics: 1, packets_sent: 1, bytes_sent: 684)

    subject.service_check('sc', 0)
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('_sc|sc|0', metrics: 0, service_checks: 1, packets_sent: 1, bytes_sent: 683)

    subject.event('ev', 'text')
    subject.flush
    expect(socket.recv[0]).to eq_with_telemetry('_e{2,4}:ev|text', metrics: 0, events: 1, packets_sent: 1, bytes_sent: 682)
  end

  context 'when some data is dropped' do
    let(:socket) do
      FakeUDPSocket.new(copy_message: true).tap do |s|
        s.error_on_send('some error')
      end
    end

    it 'handles dropped data (resets everytime)' do
      subject.gauge('test', 21)
      subject.flush(flush_telemetry: true)

      expect(subject.telemetry.metrics).to eq 0
      expect(subject.telemetry.service_checks).to eq 0
      expect(subject.telemetry.events).to eq 0
      expect(subject.telemetry.packets_sent).to eq 0
      expect(subject.telemetry.bytes_sent).to eq 0
      expect(subject.telemetry.packets_dropped).to eq 1
      expect(subject.telemetry.bytes_dropped).to eq 1353

      subject.gauge('test', 21)
      subject.flush(flush_telemetry: true)

      expect(subject.telemetry.metrics).to eq 0
      expect(subject.telemetry.service_checks).to eq 0
      expect(subject.telemetry.events).to eq 0
      expect(subject.telemetry.packets_sent).to eq 0
      expect(subject.telemetry.bytes_sent).to eq 0
      expect(subject.telemetry.packets_dropped).to eq 1
      expect(subject.telemetry.bytes_dropped).to eq 1356

      #disable network failure
      socket.error_on_send(nil)

      subject.gauge('test', 21)
      subject.flush
      expect(socket.recv[0]).to eq_with_telemetry('test:21|g', metrics: 1, service_checks: 0, events: 0, packets_dropped: 1, bytes_dropped: 1356)

      expect(subject.telemetry.metrics).to eq 0
      expect(subject.telemetry.service_checks).to eq 0
      expect(subject.telemetry.events).to eq 0
      expect(subject.telemetry.packets_sent).to eq 1
      expect(subject.telemetry.bytes_sent).to eq 684
      expect(subject.telemetry.packets_dropped).to eq 0
      expect(subject.telemetry.bytes_dropped).to eq 0
    end
  end
end
