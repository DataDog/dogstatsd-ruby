require 'spec_helper'

describe Datadog::Statsd::Telemetry do
  subject do
    described_class.new(2, container_id, external_data, cardinality,
      global_tags: global_tags,
      transport_type: :doe
    )
  end

  let(:global_tags) do
    []
  end

  let(:container_id) do
    nil
  end

  let(:external_data) do
    nil
  end

  let(:cardinality) do
    nil
  end

  describe '#would_fit_in?' do
    # we will also check the size of telemetry automatic tags
    context 'with tags ["host:myhost", "network:ethernet"]' do
      let(:global_tags) do
        ["host:myhost", "network:ethernet"]
      end

      it 'fits in an 133 bytes buffer' do
        expect(subject.would_fit_in?(133)).to be true
      end

      it 'does not fit in a 132 bytes buffer' do
        expect(subject.would_fit_in?(132)).to be false
      end
    end

    context 'with tags []' do
      it 'fits in an 104 bytes buffer' do
        expect(subject.would_fit_in?(104)).to be true
      end

      it 'does not fit in a 103 bytes buffer' do
        expect(subject.would_fit_in?(103)).to be false
      end
    end
  end

  describe '#should_flush?' do
    before do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 12))
      allow(Process).to receive(:clock_gettime).and_return(0)

      subject
    end

    after do
      Timecop.return
    end

    context 'before the delay' do
      before do
        Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 13))
        allow(Process).to receive(:clock_gettime).and_return(1)
      end

      it 'returns false' do
        expect(subject.should_flush?).to be false
      end
    end

    context 'after the delay' do
      before do
        Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 15))
        allow(Process).to receive(:clock_gettime).and_return(3)
      end

      it 'returns true' do
        expect(subject.should_flush?).to be true
      end
    end
  end

  describe '#flush' do
    before do
      subject.sent(metrics: 1, events: 2, service_checks: 3, bytes: 4, packets: 5)
      subject.dropped_writer(bytes: 6, packets: 7)
      subject.dropped_queue(bytes: 9, packets: 8)
      subject.flush
    end

    it 'serializes the telemetry' do
      expect(subject.flush).to eq [
        "datadog.dogstatsd.client.metrics:1|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.events:2|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.service_checks:3|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.bytes_sent:4|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.bytes_dropped:15|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.bytes_dropped_queue:9|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.bytes_dropped_writer:6|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.packets_sent:5|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.packets_dropped:15|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.packets_dropped_queue:8|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.packets_dropped_writer:7|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
      ]
    end

    it do
      skip 'Ruby too old' if RUBY_VERSION < '2.3.0'
      expect do
        subject.flush
      end.to make_allocations(12)
    end
  end

  describe 'with origin fields' do
    before do
      subject.sent(metrics: 1, events: 2, service_checks: 3, bytes: 4, packets: 5)
      subject.dropped_writer(bytes: 6, packets: 7)
      subject.dropped_queue(bytes: 9, packets: 8)
      subject.flush
    end

    let(:container_id) do
      "fc7038bc73a8d3850c66ddbfb0b2901afa378bfcbb942cc384b051767e4ac6b0"
    end

    let(:external_data) do
      "it-false,cn-comp-app,pu-abebb16c-c73e-41c9-ba37-4db4e75168ac"
    end

    let(:cardinality) do
      "low"
    end

    it 'serializes the telemetry with origin fields' do
      fields = "|c:fc7038bc73a8d3850c66ddbfb0b2901afa378bfcbb942cc384b051767e4ac6b0|e:it-false,cn-comp-app,pu-abebb16c-c73e-41c9-ba37-4db4e75168ac|card:low"
      expect(subject.flush).to eq [
        "datadog.dogstatsd.client.metrics:1|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.events:2|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.service_checks:3|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.bytes_sent:4|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.bytes_dropped:15|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.bytes_dropped_queue:9|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.bytes_dropped_writer:6|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.packets_sent:5|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.packets_dropped:15|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.packets_dropped_queue:8|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
        "datadog.dogstatsd.client.packets_dropped_writer:7|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe#{fields}",
      ]
    end

    it do
      skip 'Ruby too old' if RUBY_VERSION < '2.3.0'
      expect do
        subject.flush
      end.to make_allocations(12)
    end
  end

  describe '#reset' do
    before do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 12))
      allow(Process).to receive(:clock_gettime).and_return(0)

      subject.sent(metrics: 1, events: 2, service_checks: 3, bytes: 4, packets: 5)
      subject.dropped_writer(bytes: 6, packets: 7)
      subject.dropped_queue(bytes: 9, packets: 7)
    end

    after do
      Timecop.return
    end

    it 'resets the flush time' do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 15))
      allow(Process).to receive(:clock_gettime).and_return(3)

      expect do
        subject.reset
      end.to change { subject.should_flush? }.from(true).to(false)
    end

    it 'resets the metrics sent' do
      expect do
        subject.reset
      end.to change { subject.metrics }.from(1).to(0)
    end

    it 'resets the events sent' do
      expect do
        subject.reset
      end.to change { subject.events }.from(2).to(0)
    end

    it 'resets the service_checks sent' do
      expect do
        subject.reset
      end.to change { subject.service_checks }.from(3).to(0)
    end

    it 'resets the bytes_sent' do
      expect do
        subject.reset
      end.to change { subject.bytes_sent }.from(4).to(0)
    end

    it 'resets the packets_sent' do
      expect do
        subject.reset
      end.to change { subject.packets_sent }.from(5).to(0)
    end

    it 'resets the bytes_dropped' do
      expect do
        subject.reset
      end.to change { subject.bytes_dropped}.from(15).to(0)
    end

    it 'resets the bytes_dropped_queue' do
      expect do
        subject.reset
      end.to change { subject.bytes_dropped_queue }.from(9).to(0)
    end

    it 'resets the bytes_dropped_writer' do
      expect do
        subject.reset
      end.to change { subject.bytes_dropped_writer }.from(6).to(0)
    end

    it 'resets the packets_dropped' do
      expect do
        subject.reset
      end.to change { subject.packets_dropped}.from(14).to(0)
    end

    it 'resets the packets_dropped_queue' do
      expect do
        subject.reset
      end.to change { subject.packets_dropped_queue }.from(7).to(0)
    end

    it 'resets the packets_dropped_writer' do
      expect do
        subject.reset
      end.to change { subject.packets_dropped_writer }.from(7).to(0)
    end
  end

  describe '#sent' do
    context 'when bumping metrics' do
      it 'has bumped metrics by the right amount' do
        expect do
          subject.sent(metrics: 3)
        end.to change { subject.metrics }.from(0).to(3)
      end
    end

    context 'when bumping events' do
      it 'has bumped events by the right amount' do
        expect do
          subject.sent(events: 3)
        end.to change { subject.events }.from(0).to(3)
      end
    end

    context 'when bumping service_checks' do
      it 'has bumped service_checks by the right amount' do
        expect do
          subject.sent(service_checks: 3)
        end.to change { subject.service_checks }.from(0).to(3)
      end
    end

    context 'when bumping bytes' do
      it 'has bumped bytes_sent by the right amount' do
        expect do
          subject.sent(bytes: 3)
        end.to change { subject.bytes_sent }.from(0).to(3)
      end
    end

    context 'when bumping packets' do
      it 'has bumped packets_sent by the right amount' do
        expect do
          subject.sent(packets: 3)
        end.to change { subject.packets_sent }.from(0).to(3)
      end
    end
  end

  describe '#dropped_queue' do
    context 'when bumping bytes' do
      it 'has bumped bytes_dropped_queue by the right amount' do
        expect do
          subject.dropped_queue(bytes: 3)
        end.to change { subject.bytes_dropped_queue }.from(0).to(3)
      end

      it 'has bumped bytes_dropped by the right amount' do
        expect do
          subject.dropped_queue(bytes: 3)
        end.to change { subject.bytes_dropped }.from(0).to(3)
      end
    end

    context 'when bumping packets' do
      it 'has bumped packets_dropped_queue by the right amount' do
        expect do
          subject.dropped_queue(packets: 3)
        end.to change { subject.packets_dropped_queue }.from(0).to(3)
      end

      it 'has bumped packets_dropped by the right amount' do
        expect do
          subject.dropped_queue(packets: 3)
        end.to change { subject.packets_dropped }.from(0).to(3)
      end
    end
  end

  describe '#dropped_writer' do
    context 'when bumping bytes' do
      it 'has bumped bytes_dropped_writer by the right amount' do
        expect do
          subject.dropped_writer(bytes: 3)
        end.to change { subject.bytes_dropped_writer }.from(0).to(3)
      end

      it 'has bumped bytes_dropped by the right amount' do
        expect do
          subject.dropped_writer(bytes: 3)
        end.to change { subject.bytes_dropped }.from(0).to(3)
      end
    end

    context 'when bumping packets' do
      it 'has bumped packets_dropped_writer by the right amount' do
        expect do
          subject.dropped_writer(packets: 3)
        end.to change { subject.packets_dropped_writer }.from(0).to(3)
      end

      it 'has bumped packets_dropped by the right amount' do
        expect do
          subject.dropped_writer(packets: 3)
        end.to change { subject.packets_dropped }.from(0).to(3)
      end
    end
  end
end
