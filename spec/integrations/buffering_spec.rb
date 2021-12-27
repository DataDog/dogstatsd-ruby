# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'Buffering integration testing' do |single_thread|
  subject do
    Datadog::Statsd.new('localhost', 1234,
      telemetry_flush_interval: -1,
      telemetry_enable: false,
      single_thread: single_thread,
      buffer_max_pool_size: buffer_max_pool_size,
    )
  end
  let(:socket) { FakeUDPSocket.new(copy_message: true) }


  let(:buffer_max_pool_size) do
    2
  end

  before do
    allow(Socket).to receive(:new).and_return(socket)
    allow(UDPSocket).to receive(:new).and_return(socket)
  end

  it 'does not not send anything when the buffer is empty' do
    subject.flush(sync: true)

    expect(socket.recv).to be_nil
  end

  it 'the batch compatility method properly uses the buffer max pool size' do
    subject.batch do |s|
      s.increment('mycounter')
      s.increment('myothercounter')
      s.decrement('anothercounter')
      s.increment('myothercounter')
      s.decrement('yetanothercounter')
    end
    # multiple reads since buffer_max_pool_size == 2
    expect(socket.recv[0]).to eq("mycounter:1|c\nmyothercounter:1|c")
    expect(socket.recv[0]).to eq("anothercounter:-1|c\nmyothercounter:1|c")
    expect(socket.recv[0]).to eq("yetanothercounter:-1|c")
  end

  it 'sends single samples in one packet' do
    subject.increment('mycounter')

    subject.flush(sync: true)

    expect(socket.recv[0]).to eq 'mycounter:1|c'
  end

  it 'sends multiple samples in one packet' do
    subject.increment('mycounter')
    subject.decrement('myothercounter')
    subject.decrement('anothercounter')

    subject.sync_with_outbound_io

    expect(socket.recv[0]).to eq("mycounter:1|c\nmyothercounter:-1|c")
    # last value is still buffered
    expect(socket.recv).to be_nil
  end

  context 'when testing payload size limits' do
    let(:buffer_max_pool_size) do
      nil
    end

    it 'the batch compatility method is flushing everything in one time' do
      subject.batch do |s|
        s.increment('mycounter')
        s.increment('myothercounter')
        s.decrement('anothercounter')
        s.increment('myothercounter')
        s.decrement('yetanothercounter')
      end
      expect(socket.recv[0]).to eq("mycounter:1|c\nmyothercounter:1|c\nanothercounter:-1|c\nmyothercounter:1|c\nyetanothercounter:-1|c")
    end

    it 'flushes when the buffer gets too big' do
      expected_message = 'mycounter:1|c'

      # increment a counter to fill the buffer and trigger buffer flush
      buffer_size = Datadog::Statsd::UDP_DEFAULT_BUFFER_SIZE

      trigger_size = (buffer_size * (1 - Datadog::Statsd::MessageBuffer::PAYLOAD_SIZE_TOLERANCE)).round

      message_size = expected_message.bytesize + 1 # +1 for "\n" between messages
      number_of_messages_to_fill_the_buffer = (trigger_size / message_size) + 1 # +1 for filling buffer and triggering
      theoretical_reply = Array.new(number_of_messages_to_fill_the_buffer) { expected_message }

      (number_of_messages_to_fill_the_buffer + 1).times do
        subject.increment('mycounter')
      end

      subject.sync_with_outbound_io

      expect(socket.recv[0]).to eq theoretical_reply.join("\n")

      subject.flush(sync: true)

      # We increment the telemetry metrics count when we receive it, not when
      # flush. This means that the last metric (who filled the buffer and triggered a
      # flush) increment the telemetry but was not sent. Then once the 'do' block
      # finishes we flush the buffer with a telemtry of 0 metrics being received.
      expect(socket.recv[0]).to eq expected_message
    end
  end

  context 'when testing with all data types' do
    let(:buffer_max_pool_size) do
      nil
    end

    it 'handles all data types' do
      subject.increment('test', 1)
      subject.decrement('test', 1)
      subject.count('test', 21)
      subject.gauge('test', 21)
      subject.histogram('test', 21)
      subject.timing('test', 21)
      subject.set('test', 21)
      subject.service_check('sc', 0)
      subject.event('ev', 'text')

      subject.flush(flush_telemetry: true, sync: true)

      expect(socket.recv[0]).to eq "test:1|c\ntest:-1|c\ntest:21|c\ntest:21|g\ntest:21|h\ntest:21|ms\ntest:21|s\n_sc|sc|0\n_e{2,4}:ev|text"
    end
  end

  context 'with telemetry' do
    subject do
      Datadog::Statsd.new('localhost', 1234,
        telemetry_flush_interval: 60,
        buffer_max_pool_size: buffer_max_pool_size,
        single_thread: single_thread,
      )
    end

    let(:buffer_max_pool_size) do
      13 # enough messages to include the telemetry 
    end

    it 'increments telemetry correctly' do
      subject.gauge('mygauge', 10)
      subject.gauge('myothergauge', 20)

      subject.flush(flush_telemetry: true, sync: true)

      expect(socket.recv[0]).to eq_with_telemetry("mygauge:10|g\nmyothergauge:20|g", bytes_sent: 0, packets_sent: 0, metrics: 2)

      subject.increment('mycounter')

      subject.flush(flush_telemetry: true, sync: true)

      expect(socket.recv[0]).to eq_with_telemetry('mycounter:1|c', bytes_sent: 1124, packets_sent: 1, metrics: 1)

      subject.increment('myothercounter')

      subject.flush(flush_telemetry: true, sync: true)

      subject.increment('anoothercounter')

      subject.sync_with_outbound_io

      expect(socket.recv[0]).to eq_with_telemetry('myothercounter:1|c', bytes_sent: 1110, packets_sent: 1, metrics: 1)
      # last value is still buffered
      expect(socket.recv).to be_nil
    end

    context 'when testing with all data types' do
      let(:buffer_max_pool_size) do
        nil
      end

      it 'handles all data types and updates telemetry correctly' do
        subject.increment('test', 1)
        subject.decrement('test', 1)
        subject.count('test', 21)
        subject.gauge('test', 21)
        subject.histogram('test', 21)
        subject.timing('test', 21)
        subject.set('test', 21)
        subject.service_check('sc', 0)
        subject.event('ev', 'text')

        subject.flush(flush_telemetry: true, sync: true)

        expect(socket.recv[0]).to eq_with_telemetry("test:1|c\ntest:-1|c\ntest:21|c\ntest:21|g\ntest:21|h\ntest:21|ms\ntest:21|s\n_sc|sc|0\n_e{2,4}:ev|text",
          metrics: 7,
          service_checks: 1,
          events: 1
        )

        expect(subject.telemetry.metrics).to eq 0
        expect(subject.telemetry.service_checks).to eq 0
        expect(subject.telemetry.events).to eq 0
        expect(subject.telemetry.packets_sent).to eq 1
        expect(subject.telemetry.bytes_sent).to eq 1188
      end
    end
  end
end

describe 'Single threaded mode' do
  it_behaves_like 'Buffering integration testing', "true"
end

describe 'Multi threaded mode' do
  it_behaves_like 'Buffering integration testing', "false"
end
