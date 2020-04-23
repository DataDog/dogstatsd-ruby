# frozen_string_literal: true

require 'spec_helper'

describe 'Buffering integration testing' do
  let(:socket) { FakeUDPSocket.new }

  subject do
    Datadog::Statsd.new('localhost', 1234,
      telemetry_flush_interval: -1,
      max_buffer_pool_size: max_buffer_pool_size,
    )
  end

  let(:max_buffer_pool_size) do
    2
  end

  before do
    allow(Socket).to receive(:new).and_return(socket)
    allow(UDPSocket).to receive(:new).and_return(socket)
  end

  it 'does not not send anything when the buffer is empty' do
    subject.flush

    expect(socket.recv).to be_nil
  end

  it 'sends single samples in one packet' do
    subject.increment('mycounter')

    subject.flush

    expect(socket.recv[0]).to eq_with_telemetry 'mycounter:1|c'
  end

  it 'sends multiple samples in one packet' do
    subject.increment('mycounter')
    subject.decrement('myothercounter')
    subject.decrement('anothercounter')

    expect(socket.recv[0]).to eq_with_telemetry("mycounter:1|c\nmyothercounter:-1|c", metrics: 2)
    # last value is still buffered
    expect(socket.recv).to be_nil
  end

  it 'increments telemetry correctly' do
    subject.gauge('mygauge', 10)
    subject.gauge('myothergauge', 20)

    subject.increment('mycounter')

    subject.flush

    subject.increment('myothercounter')

    subject.flush

    subject.increment('anoothercounter')

    expect(socket.recv[0]).to eq_with_telemetry("mygauge:10|g\nmyothergauge:20|g", metrics: 2)
    expect(socket.recv[0]).to eq_with_telemetry('mycounter:1|c', bytes_sent: 702, packets_sent: 1)
    expect(socket.recv[0]).to eq_with_telemetry('myothercounter:1|c', bytes_sent: 687, packets_sent: 1)
    # last value is still buffered
    expect(socket.recv).to be_nil
  end

  context 'when testing payload size limits' do
    let(:max_buffer_pool_size) do
      nil
    end

    # HACK: this test breaks encapsulation
    before do
      def subject.telemetry
        @telemetry
      end
    end

    it 'flushes when the buffer gets too big' do
      expected_message = 'mycounter:1|c'

      # increment a counter to fill the buffer and trigger buffer flush
      buffer_size = Datadog::Statsd::UDP_DEFAULT_BUFFER_SIZE - subject.telemetry.estimate_max_size

      trigger_size = (buffer_size * (1 - Datadog::Statsd::MessageBuffer::PAYLOAD_SIZE_TOLERANCE)).round

      message_size = expected_message.bytesize + 1 # +1 for "\n" between messages
      number_of_messages_to_fill_the_buffer = (trigger_size / message_size) + 1 # +1 for filling buffer and triggering
      theoretical_reply = Array.new(number_of_messages_to_fill_the_buffer) { expected_message }

      (number_of_messages_to_fill_the_buffer + 1).times do
        subject.increment('mycounter')
      end

      expect(socket.recv[0]).to eq_with_telemetry(theoretical_reply.join("\n"), metrics: number_of_messages_to_fill_the_buffer)

      subject.flush

      # We increment the telemetry metrics count when we receive it, not when
      # flush. This means that the last metric (who filled the buffer and triggered a
      # flush) increment the telemetry but was not sent. Then once the 'do' block
      # finishes we flush the buffer with a telemtry of 0 metrics being received.
      expect(socket.recv[0]).to eq_with_telemetry(expected_message, metrics: 1, bytes_sent: 7771, packets_sent: 1)
    end
  end

  context 'when testing with all data types' do
    let(:max_buffer_pool_size) do
      nil
    end

    # HACK: this test breaks encapsulation
    before do
      def subject.telemetry
        @telemetry
      end
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

      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry("test:1|c\ntest:-1|c\ntest:21|c\ntest:21|g\ntest:21|h\ntest:21|ms\ntest:21|s\n_sc|sc|0\n_e{2,4}:ev|text",
        metrics: 7,
        service_checks: 1,
        events: 1
      )

      expect(subject.telemetry.flush).to eq_with_telemetry('', metrics: 0, service_checks: 0, events: 0, packets_sent: 1, bytes_sent: 766)
    end
  end
end
