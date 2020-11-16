require 'spec_helper'

describe Datadog::Statsd do
  let(:socket) { FakeUDPSocket.new(copy_message: true) }

  subject do
    described_class.new('localhost', 1234,
      namespace: namespace,
      sample_rate: sample_rate,
      tags: tags,
      logger: logger,
      telemetry_flush_interval: -1,
    )
  end

  let(:namespace) { 'sample_ns' }
  let(:sample_rate) { nil }
  let(:tags) { %w[abc def] }
  let(:logger) do
    Logger.new(log).tap do |logger|
      logger.level = Logger::INFO
    end
  end
  let(:log) { StringIO.new }

  before do
    allow(Socket).to receive(:new).and_return(socket)
    allow(UDPSocket).to receive(:new).and_return(socket)
  end

  describe '#initialize' do
    context 'when using provided values' do
      it 'sets the host correctly' do
        expect(subject.host).to eq 'localhost'
      end

      it 'sets the port correctly' do
        expect(subject.port).to eq 1234
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


      around do |example|
        ClimateControl.modify(
          'DD_AGENT_HOST' => 'myhost',
          'DD_DOGSTATSD_PORT' => '4321',
          'DD_ENTITY_ID' => '04652bb7-19b7-11e9-9cc6-42010a9c016d',
          'DD_ENV' => 'staging',
          'DD_SERVICE' => 'billing-service',
          'DD_VERSION' => '0.1.0-alpha',
          'DD_TAGS' => 'ghi,team:qa'
        ) do
          example.run
        end
      end

      it 'sets the host using the env var DD_AGENT_HOST' do
        expect(subject.host).to eq 'myhost'
      end

      it 'sets the port using the env var DD_DOGSTATSD_PORT' do
        expect(subject.port).to eq 4321
      end

      it 'sets the entity tag using ' do
        expect(subject.tags).to match_array [
          'abc',
          'def',
          'ghi',
          'env:staging',
          'service:billing-service',
          'team:qa',
          'version:0.1.0-alpha',
          'dd.internal.entity_id:04652bb7-19b7-11e9-9cc6-42010a9c016d'
        ]
      end
    end

    context 'when using default values' do
      subject do
        described_class.new
      end

      it 'sets the host to default values' do
        expect(subject.host).to eq '127.0.0.1'
      end

      it 'sets the port to default values' do
        expect(subject.port).to eq 8125
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
        FakeUDPSocket.new(copy_message: true)
      end

      context 'when using a host and a port' do
        before do
          allow(UDPSocket).to receive(:new).and_return(fake_socket)
        end

        it 'uses an UDP socket' do
          expect(subject.transport_type).to eq :udp
        end

        it 'gives the right default size to the message buffer' do
          expect(Datadog::Statsd::MessageBuffer)
            .to receive(:new)
            .with(anything, hash_including(max_payload_size: 1_432))

          subject
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
          expect(subject.transport_type).to eq :uds
        end

        it 'gives the right default size to the message buffer' do
          expect(Datadog::Statsd::MessageBuffer)
            .to receive(:new)
            .with(anything, hash_including(max_payload_size: 8_192))

          subject
        end
      end
    end
  end

  describe '#open' do
    before do
      allow(described_class)
        .to receive(:new)
        .and_return(fake_statsd)
    end

    let(:fake_statsd) do
      instance_double(described_class, close: true)
    end

    it 'builds an instance of statsd correctly' do
      expect(described_class)
        .to receive(:new)
        .with('localhost', 1234,
          namespace: namespace,
          sample_rate: sample_rate,
          tags: tags,
        )

      described_class.open('localhost', 1234,
        namespace: namespace,
        sample_rate: sample_rate,
        tags: tags,
      ) {}
    end

    it 'yields the statsd instance' do
      expect do |block|
        described_class.open(&block)
      end.to yield_with_args(fake_statsd)
    end

    it 'closes the statsd instance' do
      expect(fake_statsd).to receive(:close)

      described_class.open {}
    end


    it 'ensures the statsd instance is closed' do
      expect(fake_statsd).to receive(:close)

      # rubocop:disable Lint/RescueWithoutErrorClass
      described_class.open do
        raise 'stop'
      end rescue nil
      # rubocop:enable Lint/RescueWithoutErrorClass
    end
  end

  describe '#increment' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'foobar:1|c' do
      let(:basic_action) do
        subject.increment('foobar', tags: action_tags)
        subject.flush
      end
    end

    it 'sends the increment' do
      subject.increment('foobar')
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry('foobar:1|c')
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'formats the message according to the statsd spec' do
        subject.increment('foobar', sample_rate: 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1|c|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the increment with the sample rate' do
        subject.increment('foobar', 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1|c|@0.5'
      end
    end

    context 'with a increment by' do
      it 'increments by the number given' do
        subject.increment('foobar', by: 5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:5|c'
      end
    end
  end

  describe '#decrement' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'foobar:-1|c' do
      let(:basic_action) do
        subject.decrement('foobar', tags: action_tags)
        subject.flush
      end
    end

    it 'sends the decrement' do
      subject.decrement('foobar')
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'foobar:-1|c'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the decrement with the sample rate' do
        subject.decrement('foobar', sample_rate: 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:-1|c|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the decrement with the sample rate' do
        subject.decrement('foobar', 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:-1|c|@0.5'
      end
    end

    context 'with a decrement by' do
      it 'decrements by the number given' do
        subject.decrement('foobar', by: 5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:-5|c'
      end
    end
  end

  describe '#count' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'foobar:123|c' do
      let(:basic_action) do
        subject.count('foobar', 123, tags: action_tags)
        subject.flush
      end
    end

    it 'sends the count' do
      subject.count('foobar', 123)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'foobar:123|c'
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the count with sample rate' do
        subject.count('foobar', 123, 0.1)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:123|c|@0.1'
      end
    end
  end

  describe '#gauge' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'begrutten-suffusion:536|g' do
      let(:basic_action) do
        subject.gauge('begrutten-suffusion', 536, tags: action_tags)
        subject.flush
      end
    end

    it 'sends the gauge' do
      subject.gauge('begrutten-suffusion', 536)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g'
    end

    it 'sends the gauge with sequential values' do
      subject.gauge('begrutten-suffusion', 536)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g'

      subject.gauge('begrutten-suffusion', -107.3)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:-107.3|g', bytes_sent: 697, packets_sent: 1
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the gauge with the sample rate' do
        subject.gauge('begrutten-suffusion', 536, sample_rate: 0.1)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g|@0.1'
      end
    end

    describe 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'formats the message according to the statsd spec' do
        subject.gauge('begrutten-suffusion', 536, 0.1)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g|@0.1'
      end
    end
  end

  describe '#histogram' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'ohmy:536|h' do
      let(:basic_action) do
        subject.histogram('ohmy', 536, tags: action_tags)
        subject.flush
      end
    end

    it 'sends the histogram' do
      subject.histogram('ohmy', 536)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'ohmy:536|h'
    end

    it 'sends the histogram with sequential values' do
      subject.histogram('ohmy', 536)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'ohmy:536|h'

      subject.histogram('ohmy', -107.3)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'ohmy:-107.3|h', bytes_sent: 682, packets_sent: 1
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the histogram with the sample rate' do
        subject.gauge('begrutten-suffusion', 536, sample_rate: 0.1)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g|@0.1'
      end
    end
  end

  describe '#set' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'myset:536|s' do
      let(:basic_action) do
        subject.set('myset', 536, tags: action_tags)
        subject.flush
      end
    end

    it 'sends the set' do
      subject.set('my.set', 536)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'my.set:536|s'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the set with the sample rate' do
        subject.set('my.set', 536, sample_rate: 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'my.set:536|s|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the set with the sample rate' do
        subject.set('my.set', 536, 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'my.set:536|s|@0.5'
      end
    end
  end

  describe '#timing' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'foobar:500|ms' do
      let(:basic_action) do
        subject.timing('foobar', 500, tags: action_tags)
        subject.flush
      end
    end

    it 'sends the timing' do
      subject.timing('foobar', 500)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'foobar:500|ms'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the timing with the sample rate' do
        subject.timing('foobar', 500, sample_rate: 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:500|ms|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the timing with the sample rate' do
        subject.timing('foobar', 500, 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:500|ms|@0.5'
      end
    end
  end

  describe '#time' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    let(:before_date) do
      DateTime.new(2020, 2, 25, 12, 12, 12)
    end

    let(:after_date) do
      DateTime.new(2020, 2, 25, 12, 12, 13)
    end

    before do
      Timecop.freeze(before_date)
      allow(Process).to receive(:clock_gettime).and_return(0) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
    end

    it_behaves_like 'a metrics method', 'foobar:1000|ms' do
      let(:basic_action) do
        subject.time('foobar', tags: action_tags) do
          Timecop.travel(after_date)
          allow(Process).to receive(:clock_gettime).and_return(1) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
        end

        subject.flush
      end
    end

    context 'when actually testing time' do
      it 'sends the timing' do
        subject.time('foobar') do
          Timecop.travel(after_date)
          allow(Process).to receive(:clock_gettime).and_return(1) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
        end

        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1000|ms'
      end

      it 'ensures the timing is sent' do
        # rubocop:disable Lint/RescueWithoutErrorClass
        subject.time('foobar') do
          Timecop.travel(after_date)
          allow(Process).to receive(:clock_gettime).and_return(1) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
          raise 'stop'
        end rescue nil
        # rubocop:enable Lint/RescueWithoutErrorClass

        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1000|ms'
      end
    end

    it 'returns the result of the block' do
      expect(subject.time('foobar') { 'test' }).to eq 'test'
    end

    it 'does not catch errors if block is failing' do
      expect do
        subject.time('foobar') do
          raise 'yolo'
        end
      end.to raise_error(StandardError, 'yolo')
    end

    it 'can run without "PROCESS_TIME_SUPPORTED"' do
      stub_const('PROCESS_TIME_SUPPORTED', false)

      expect do
        subject.time('foobar') {}
      end.not_to raise_error
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the timing with the sample rate' do
        subject.time('foobar', sample_rate: 0.5) do
          Timecop.travel(after_date)
          allow(Process).to receive(:clock_gettime).and_return(1) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
        end

        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1000|ms|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the timing with the sample rate' do
        subject.time('foobar', 0.5) do
          Timecop.travel(after_date)
          allow(Process).to receive(:clock_gettime).and_return(1) if Datadog::Statsd::PROCESS_TIME_SUPPORTED
        end

        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1000|ms|@0.5'
      end
    end
  end

  describe '#distribution' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'begrutten-suffusion:536|d' do
      let(:basic_action) do
        subject.distribution('begrutten-suffusion', 536, tags: action_tags)
        subject.flush
      end
    end

    it 'sends the distribution' do
      subject.distribution('begrutten-suffusion', 536)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|d'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the set with the sample rate' do
        subject.distribution('begrutten-suffusion', 536, sample_rate: 0.5)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|d|@0.5'
      end
    end
  end

  describe '#event' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }
    let(:title) { 'this is a title' }
    let(:text) { 'this is a longer text' }
    let(:timestamp) do
      Time.parse('01-01-2000').to_i
    end

    it_behaves_like 'a taggable method', '_e{15,21}:this is a title|this is a longer text', metrics: 0, events: 1 do
      let(:basic_action) do
        subject.event(title, text, tags: action_tags)
        subject.flush
      end
    end

    it 'sends events with title and text' do
      subject.event(title, text)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text', metrics: 0, events: 1)
    end

    context 'when having line breaks in text or title' do
      let(:title) { "this is a\ntitle" }
      let(:text) { "this is a longer\ntext" }

      it 'sends events with title and text' do
        subject.event(title, text)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry('_e{16,22}:this is a\ntitle|this is a longer\ntext', metrics: 0, events: 1)
      end
    end

    context 'with a known alert type' do
      it 'sends events with title and text along with a tag for the alert type' do
        subject.event(title, text, alert_type: 'warning')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|t:warning', metrics: 0, events: 1)
      end
    end

    context 'with an unknown alert type' do
      it 'sends events with title and text along with a tag for the alert type' do
        subject.event(title, text, alert_type: 'yolo')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|t:yolo', metrics: 0, events: 1)
      end
    end

    context 'with a known priority' do
      it 'sends events with title and text along with a tag for the priority' do
        subject.event(title, text, priority: 'low')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|p:low', metrics: 0, events: 1)
      end
    end

    context 'with an unknown priority' do
      it 'sends events with title and text along with a tag for the priority' do
        subject.event(title, text, priority: 'yolo')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|p:yolo', metrics: 0, events: 1)
      end
    end

    context 'with a timestamp event date' do
      it 'sends events with title and text along with a date timestamp' do
        subject.event(title, text, date_happened: timestamp)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|d:#{timestamp}", metrics: 0, events: 1)
      end
    end

    context 'with a string event date' do
      it 'sends events with title and text along with a date timestamp' do
        subject.event(title, text, date_happened: timestamp.to_s)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|d:#{timestamp}", metrics: 0, events: 1)
      end
    end

    context 'with a hostname' do
      it 'sends events with title and text along with a hostname' do
        subject.event(title, text, hostname: 'chihiro')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|h:chihiro", metrics: 0, events: 1)
      end
    end

    context 'with an aggregation key' do
      it 'sends events with title and text along with the aggregation key' do
        subject.event(title, text, aggregation_key: 'key 1')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|k:key 1", metrics: 0, events: 1)
      end
    end

    context 'with an source type name' do
      it 'sends events with title and text along with the source type name' do
        subject.event(title, text, source_type_name: 'source 1')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|s:source 1", metrics: 0, events: 1)
      end
    end

    context 'with several parameters (hostname, alert_type, priority, source)' do
      it 'sends events with title and text along with all the parameters' do
        subject.event(title, text, hostname: 'myhost', alert_type: 'warning', priority: 'low', source_type_name: 'source')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|h:myhost|p:low|s:source|t:warning", metrics: 0, events: 1)
      end
    end
  end

  describe '#service_check' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }
    let(:name) { 'windmill' }
    let(:status) { 'grinding' }
    let(:timestamp) do
      Time.parse('01-01-2000').to_i
    end

    it_behaves_like 'a taggable method', '_sc|windmill|grinding', metrics: 0, service_checks: 1 do
      let(:basic_action) do
        subject.service_check(name, status, tags: action_tags)
        subject.flush
      end
    end

    it 'sends service check with name and status' do
      subject.service_check(name, status)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry('_sc|windmill|grinding', metrics: 0, service_checks: 1)
    end

    context 'with hostname' do
      it 'sends service check with name and status along with hostname' do
        subject.service_check(name, status, hostname: 'amsterdam')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry('_sc|windmill|grinding|h:amsterdam', metrics: 0, service_checks: 1)
      end
    end

    context 'with message' do
      it 'sends service check with name and status along with message' do
        subject.service_check(name, status, message: 'the wind is rising')
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry('_sc|windmill|grinding|m:the wind is rising', metrics: 0, service_checks: 1)
      end
    end

    context 'with integer timestamp' do
      it 'sends service check with name and status along with timestamp' do
        subject.service_check(name, status, timestamp: timestamp)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_sc|windmill|grinding|d:#{timestamp}", metrics: 0, service_checks: 1)
      end
    end

    context 'with string timestamp' do
      it 'sends service check with name and status along with timestamp' do
        subject.service_check(name, status, timestamp: timestamp.to_s)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_sc|windmill|grinding|d:#{timestamp}", metrics: 0, service_checks: 1)
      end
    end

    context 'with several parameters (hostname, message, timestamp)' do
      it 'sends service check with name and status along with all parameters' do
        subject.service_check(name, status, hostanme: 'amsterdam', message: 'the wind is rising', timestamp: timestamp.to_s)
        subject.flush

        expect(socket.recv[0]).to eq_with_telemetry("_sc|windmill|grinding|d:#{timestamp}|m:the wind is rising", metrics: 0, service_checks: 1)
      end
    end
  end

  describe '#close' do
    before do
      # do some writing so the socket is opened
      subject.increment('lol')
      subject.flush
    end

    it 'closes the socket' do
      expect(socket).to receive(:close)

      subject.close
    end
  end

  # TODO: This specs will have to move to another class (a responsibility that we will have to separate)
  describe 'Stat names' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it 'accepts any object with #to_s as a stat name' do
      o = double('a stat', to_s: 'yolo')

      subject.increment(o)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry('yolo:1|c')
    end

    it 'accepts a class name as a stat name' do
      subject.increment(Object)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry('Object:1|c')
    end

    it 'replaces Ruby constants delimeter with graphite package name' do
      class Datadog::Statsd::SomeClass; end
      subject.increment(Datadog::Statsd::SomeClass)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'Datadog.Statsd.SomeClass:1|c'
    end

    it 'replaces statsd reserved chars in the stat name' do
      subject.increment('ray@hostname.blah|blah.blah:blah')
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'ray_hostname.blah_blah.blah_blah:1|c'
    end

    it 'works with frozen strings' do
      subject.increment('some-stat'.freeze)
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry('some-stat:1|c')
    end
  end

  # TODO: This specs will have to move to another class (a responsibility that we will have to separate)
  describe 'Tag names' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it 'replaces reserved chars for tags' do
      subject.increment('stat', tags: ['name:foo,bar|foo'])
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'stat:1|c|#name:foobarfoo'
    end

    it 'handles the cases when some tags are frozen strings' do
      subject.increment('stat', tags: ['first_tag'.freeze, 'second_tag'])
      subject.flush
    end

    it 'converts all values to strings' do
      tag = double('a tag', to_s: 'yolo')

      subject.increment('stat', tags: [tag])
      subject.flush

      expect(socket.recv[0]).to eq_with_telemetry 'stat:1|c|#yolo'
    end
  end
end