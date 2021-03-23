require 'spec_helper'

describe Datadog::Statsd::Telemetry do
  subject do
    described_class.new(2,
      global_tags: global_tags,
      transport_type: :doe
    )
  end

  let(:global_tags) do
    []
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
      allow(Process).to receive(:clock_gettime).and_return(0) if Datadog::Statsd::PROCESS_TIME_SUPPORTED

      subject
    end

    after do
      Timecop.return
    end

    context 'before the delay' do
      before do
        Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 13))
        allow(Process).to receive(:clock_gettime).and_return(1) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
      end

      it 'returns false' do
        expect(subject.should_flush?).to be false
      end
    end

    context 'after the delay' do
      before do
        Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 15))
        allow(Process).to receive(:clock_gettime).and_return(3) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
      end

      it 'returns true' do
        expect(subject.should_flush?).to be true
      end
    end
  end

  describe '#flush' do
    before do
      subject.sent(metrics: 1, events: 2, service_checks: 3, bytes: 4, packets: 5)
      subject.dropped(bytes: 6, packets: 7)
      subject.flush
    end

    it 'serializes the telemetry' do
      expect(subject.flush).to eq [
        "datadog.dogstatsd.client.metrics:1|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.events:2|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.service_checks:3|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.bytes_sent:4|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.bytes_dropped:6|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.packets_sent:5|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
        "datadog.dogstatsd.client.packets_dropped:7|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:doe",
      ]
    end

    context do
      before do
        skip 'Ruby too old' if RUBY_VERSION < '2.3.0'
      end

      it 'makes only 8 allocations' do
        expect do
          subject.flush
        end.to make_allocations(8)
      end
    end
  end

  describe '#reset' do
    before do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 12))
      allow(Process).to receive(:clock_gettime).and_return(0) if Datadog::Statsd::PROCESS_TIME_SUPPORTED

      subject.sent(metrics: 1, events: 2, service_checks: 3, bytes: 4, packets: 5)
      subject.dropped(bytes: 6, packets: 7)
    end

    after do
      Timecop.return
    end

    it 'resets the flush time' do
      Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 15))
      allow(Process).to receive(:clock_gettime).and_return(3) if Datadog::Statsd::PROCESS_TIME_SUPPORTED

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
      end.to change { subject.bytes_dropped }.from(6).to(0)
    end

    it 'resets the packets_dropped' do
      expect do
        subject.reset
      end.to change { subject.packets_dropped }.from(7).to(0)
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

  describe '#dropped' do
    context 'when bumping bytes' do
      it 'has bumped bytes_dropped by the right amount' do
        expect do
          subject.dropped(bytes: 3)
        end.to change { subject.bytes_dropped }.from(0).to(3)
      end
    end

    context 'when bumping packets' do
      it 'has bumped packets_dropped by the right amount' do
        expect do
          subject.dropped(packets: 3)
        end.to change { subject.packets_dropped }.from(0).to(3)
      end
    end
  end
end
