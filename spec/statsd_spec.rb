require 'spec_helper'

describe Datadog::Statsd do
  let(:socket) { FakeUDPSocket.new }

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

      described_class.open do
        raise 'stop'
      end rescue nil
    end
  end

  describe '#increment' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it_behaves_like 'a metrics method', 'foobar:1|c' do
      let(:basic_action) do
        subject.increment('foobar', tags: action_tags)
      end
    end

    it 'sends the increment' do
      subject.increment('foobar')

      expect(socket.recv[0]).to eq_with_telemetry('foobar:1|c')
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'formats the message according to the statsd spec' do
        subject.increment('foobar', sample_rate: 0.5)
        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1|c|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the increment with the sample rate' do
        subject.increment('foobar', 0.5)
        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1|c|@0.5'
      end
    end

    context 'with a increment by' do
      it 'increments by the number given' do
        subject.increment('foobar', by: 5)
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
      end
    end

    it 'sends the decrement' do
      subject.decrement('foobar')
      expect(socket.recv[0]).to eq_with_telemetry 'foobar:-1|c'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the decrement with the sample rate' do
        subject.decrement('foobar', sample_rate: 0.5)
        expect(socket.recv[0]).to eq_with_telemetry 'foobar:-1|c|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the decrement with the sample rate' do
        subject.decrement('foobar', 0.5)
        expect(socket.recv[0]).to eq_with_telemetry 'foobar:-1|c|@0.5'
      end
    end

    context 'with a decrement by' do
      it 'decrements by the number given' do
        subject.decrement('foobar', by: 5)
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
      end
    end

    it 'sends the count' do
      subject.count('foobar', 123)
      expect(socket.recv[0]).to eq_with_telemetry 'foobar:123|c'
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the count with sample rate' do
        subject.count('foobar', 123, 0.1)
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
      end
    end

    it 'sends the gauge' do
      subject.gauge('begrutten-suffusion', 536)
      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g'
    end

    it 'sends the gauge with sequential values' do
      subject.gauge('begrutten-suffusion', 536)
      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g'

      subject.gauge('begrutten-suffusion', -107.3)
      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:-107.3|g', bytes_sent: 697, packets_sent: 1
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the gauge with the sample rate' do
        subject.gauge('begrutten-suffusion', 536, sample_rate: 0.1)
        expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|g|@0.1'
      end
    end

    describe 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'formats the message according to the statsd spec' do
        subject.gauge('begrutten-suffusion', 536, 0.1)
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
      end
    end

    it 'sends the histogram' do
      subject.histogram('ohmy', 536)
      expect(socket.recv[0]).to eq_with_telemetry 'ohmy:536|h'
    end

    it 'sends the histogram with sequential values' do
      subject.histogram('ohmy', 536)
      expect(socket.recv[0]).to eq_with_telemetry 'ohmy:536|h'

      subject.histogram('ohmy', -107.3)
      expect(socket.recv[0]).to eq_with_telemetry 'ohmy:-107.3|h', bytes_sent: 682, packets_sent: 1
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the histogram with the sample rate' do
        subject.gauge('begrutten-suffusion', 536, sample_rate: 0.1)
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
      end
    end

    it 'sends the set' do
      subject.set('my.set', 536)
      expect(socket.recv[0]).to eq_with_telemetry 'my.set:536|s'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the set with the sample rate' do
        subject.set('my.set', 536, sample_rate: 0.5)
        expect(socket.recv[0]).to eq_with_telemetry 'my.set:536|s|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the set with the sample rate' do
        subject.set('my.set', 536, 0.5)
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
      end
    end

    it 'sends the timing' do
      subject.timing('foobar', 500)
      expect(socket.recv[0]).to eq_with_telemetry 'foobar:500|ms'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the timing with the sample rate' do
        subject.timing('foobar', 500, sample_rate: 0.5)
        expect(socket.recv[0]).to eq_with_telemetry 'foobar:500|ms|@0.5'
      end
    end

    context 'with a sample rate like statsd-ruby' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the timing with the sample rate' do
        subject.timing('foobar', 500, 0.5)
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
      allow(Process).to receive(:clock_gettime).and_return(0, 1)
    end

    it_behaves_like 'a metrics method', 'foobar:1000|ms' do
      let(:basic_action) do
        subject.time('foobar', tags: action_tags) do
          Timecop.travel(after_date)
        end
      end
    end

    context 'when actually testing time' do
      it 'sends the timing' do
        subject.time('foobar') do
          Timecop.travel(after_date)
        end

        expect(socket.recv[0]).to eq_with_telemetry 'foobar:1000|ms'
      end

      it 'ensures the timing is sent' do
        subject.time('foobar') do
          Timecop.travel(after_date)
          raise 'stop'
        end rescue nil

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
        end

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
        end

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
      end
    end

    it 'sends the distribution' do
      subject.distribution('begrutten-suffusion', 536)
      expect(socket.recv[0]).to eq_with_telemetry 'begrutten-suffusion:536|d'
    end

    context 'with a sample rate' do
      before do
        allow(subject).to receive(:rand).and_return(0)
      end

      it 'sends the set with the sample rate' do
        subject.distribution('begrutten-suffusion', 536, sample_rate: 0.5)
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
      end
    end

    it 'sends events with title and text' do
      subject.event(title, text)
      expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text', metrics: 0, events: 1)
    end

    context 'when having line breaks in text or title' do
      let(:title) { "this is a\ntitle" }
      let(:text) { "this is a longer\ntext" }

      it 'sends events with title and text' do
        subject.event(title, text)
        expect(socket.recv[0]).to eq_with_telemetry('_e{16,22}:this is a\ntitle|this is a longer\ntext', metrics: 0, events: 1)
      end
    end

    context 'when the event data string too long > 8KB' do
      let(:text) { "this is a longer\ntext" * 200_000 }

      it 'raises an error' do
        expect do
          subject.event(title, text)
        end.to raise_error(RuntimeError, /payload is too big/)
      end
    end

    context 'with a known alert type' do
      it 'sends events with title and text along with a tag for the alert type' do
        subject.event(title, text, alert_type: 'warning')

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|t:warning', metrics: 0, events: 1)
      end
    end

    context 'with an unknown alert type' do
      it 'sends events with title and text along with a tag for the alert type' do
        subject.event(title, text, alert_type: 'yolo')

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|t:yolo', metrics: 0, events: 1)
      end
    end

    context 'with a known priority' do
      it 'sends events with title and text along with a tag for the priority' do
        subject.event(title, text, priority: 'low')

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|p:low', metrics: 0, events: 1)
      end
    end

    context 'with an unknown priority' do
      it 'sends events with title and text along with a tag for the priority' do
        subject.event(title, text, priority: 'yolo')

        expect(socket.recv[0]).to eq_with_telemetry('_e{15,21}:this is a title|this is a longer text|p:yolo', metrics: 0, events: 1)
      end
    end

    context 'with a timestamp event date' do
      it 'sends events with title and text along with a date timestamp' do
        subject.event(title, text, date_happened: timestamp)

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|d:#{timestamp}", metrics: 0, events: 1)
      end
    end

    context 'with a string event date' do
      it 'sends events with title and text along with a date timestamp' do
        subject.event(title, text, date_happened: timestamp.to_s)

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|d:#{timestamp}", metrics: 0, events: 1)
      end
    end

    context 'with a hostname' do
      it 'sends events with title and text along with a hostname' do
        subject.event(title, text, hostname: 'chihiro')

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|h:chihiro", metrics: 0, events: 1)
      end
    end

    context 'with an aggregation key' do
      it 'sends events with title and text along with the aggregation key' do
        subject.event(title, text, aggregation_key: 'key 1')

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|k:key 1", metrics: 0, events: 1)
      end
    end

    context 'with an source type name' do
      it 'sends events with title and text along with the source type name' do
        subject.event(title, text, source_type_name: 'source 1')

        expect(socket.recv[0]).to eq_with_telemetry("_e{15,21}:this is a title|this is a longer text|s:source 1", metrics: 0, events: 1)
      end
    end

    context 'with several parameters (hostname, alert_type, priority, source)' do
      it 'sends events with title and text along with all the parameters' do
        subject.event(title, text, hostname: 'myhost', alert_type: 'warning', priority: 'low', source_type_name: 'source')

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
      end
    end

    it 'sends service check with name and status' do
      subject.service_check(name, status)
      expect(socket.recv[0]).to eq_with_telemetry('_sc|windmill|grinding', metrics: 0, service_checks: 1)
    end

    context 'with hostname' do
      it 'sends service check with name and status along with hostname' do
        subject.service_check(name, status, hostname: 'amsterdam')
        expect(socket.recv[0]).to eq_with_telemetry('_sc|windmill|grinding|h:amsterdam', metrics: 0, service_checks: 1)
      end
    end

    context 'with message' do
      it 'sends service check with name and status along with message' do
        subject.service_check(name, status, message: 'the wind is rising')
        expect(socket.recv[0]).to eq_with_telemetry('_sc|windmill|grinding|m:the wind is rising', metrics: 0, service_checks: 1)
      end
    end

    context 'with integer timestamp' do
      it 'sends service check with name and status along with timestamp' do
        subject.service_check(name, status, timestamp: timestamp)
        expect(socket.recv[0]).to eq_with_telemetry("_sc|windmill|grinding|d:#{timestamp}", metrics: 0, service_checks: 1)
      end
    end

    context 'with string timestamp' do
      it 'sends service check with name and status along with timestamp' do
        subject.service_check(name, status, timestamp: timestamp.to_s)
        expect(socket.recv[0]).to eq_with_telemetry("_sc|windmill|grinding|d:#{timestamp}", metrics: 0, service_checks: 1)
      end
    end

    context 'with several parameters (hostname, message, timestamp)' do
      it 'sends service check with name and status along with all parameters' do
        subject.service_check(name, status, hostanme: 'amsterdam', message: 'the wind is rising', timestamp: timestamp.to_s)
        expect(socket.recv[0]).to eq_with_telemetry("_sc|windmill|grinding|d:#{timestamp}|m:the wind is rising", metrics: 0, service_checks: 1)
      end
    end
  end

  describe '#batch' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    it 'does not not send anything when the buffer is empty' do
      subject.batch { }

      expect(socket.recv).to be_nil
    end

    it 'sends single samples in one packet' do
      subject.batch do |s|
        s.increment('mycounter')
      end

      expect(socket.recv[0]).to eq_with_telemetry 'mycounter:1|c'
    end

    it 'sends multiple samples in one packet' do
      subject.batch do |s|
        s.increment('mycounter')
        s.decrement('myothercounter')
      end

      expect(socket.recv[0]).to eq_with_telemetry("mycounter:1|c\nmyothercounter:-1|c", metrics: 2)
    end

    it 'default back to single metric packet after the block' do
      subject.batch do |s|
        s.gauge('mygauge', 10)
        s.gauge('myothergauge', 20)
      end
      subject.increment('mycounter')
      subject.increment('myothercounter')

      expect(socket.recv[0]).to eq_with_telemetry("mygauge:10|g\nmyothergauge:20|g", metrics: 2)
      expect(socket.recv[0]).to eq_with_telemetry('mycounter:1|c', bytes_sent: 702, packets_sent: 1)
      expect(socket.recv[0]).to eq_with_telemetry('myothercounter:1|c', bytes_sent: 687, packets_sent: 1)
    end

    # HACK: this test breaks encapsulation
    before do
      def subject.telemetry
        @telemetry
      end
    end

    it 'flushes when the buffer gets too big' do
      expected_message = 'mycounter:1|c'
      previous_payload_length = 0

      subject.batch do |s|
        # increment a counter to fill the buffer and trigger buffer flush
        buffer_size = Datadog::Statsd::DEFAULT_BUFFER_SIZE - subject.telemetry.estimate_max_size - 1

        number_of_messages_to_fill_the_buffer = buffer_size / (expected_message.bytesize + 1)
        theoretical_reply = Array.new(number_of_messages_to_fill_the_buffer) { expected_message }

        (number_of_messages_to_fill_the_buffer + 1).times do
          s.increment('mycounter')
        end

        expect(socket.recv[0]).to eq_with_telemetry(theoretical_reply.join("\n"), metrics: number_of_messages_to_fill_the_buffer+1)
      end

      # When the block finishes, the remaining buffer is flushed.
      #
      # We increment the telemetry metrics count when we receive it, not when
      # flush. This means that the last metric (who filled the buffer and triggered a
      # flush) increment the telemetry but was not sent. Then once the 'do' block
      # finishes we flush the buffer with a telemtry of 0 metrics being received.
      expect(socket.recv[0]).to eq_with_telemetry(expected_message, metrics: 0, bytes_sent: 8121, packets_sent: 1)
    end

    it 'batches nested batch blocks' do
      subject.batch do
        subject.increment('level-1')
        subject.batch do
          subject.increment('level-2')
        end
        subject.increment('level-1-again')
      end
      # all three should be sent in a single batch when the outer block finishes
      expect(socket.recv[0]).to eq_with_telemetry("level-1:1|c\nlevel-2:1|c\nlevel-1-again:1|c", metrics: 3)
      # we should revert back to sending single metric packets
      subject.increment('outside')
      expect(socket.recv[0]).to eq_with_telemetry('outside:1|c', bytes_sent: 713, packets_sent: 1)
    end
  end

  describe '#close' do
    before do
      # do some writing so the socket is opened
      subject.increment('lol')
    end

    it 'closes the socket' do
      expect(socket).to receive(:close)

      subject.close
    end
  end

  # TODO: This specs will have to move to another integration test dedicated to telemetry
  describe 'telemetry' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    context 'when disabling telemetry' do
      subject do
        described_class.new('localhost', 1234,
          namespace: namespace,
          sample_rate: sample_rate,
          tags: tags,
          logger: logger,
          disable_telemetry: true,
        )
      end

      it 'does not send any telemetry' do
        subject.count("test", 21)

        expect(socket.recv[0]).to eq 'test:21|c'
      end
    end

    it 'is enabled by default' do
      subject.count('test', 21)

      expect(socket.recv[0]).to eq_with_telemetry 'test:21|c'
    end

    context 'when flusing only every 2 seconds' do
      before do
        Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 12))
        subject
      end

      after do
        Timecop.return
      end

      subject do
        described_class.new('localhost', 1234,
          namespace: namespace,
          sample_rate: sample_rate,
          tags: tags,
          logger: logger,
          telemetry_flush_interval: 2,
        )
      end

      it 'does not send telemetry before the delay' do
        Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 13))

        subject.count('test', 21)

        expect(socket.recv[0]).to eq 'test:21|c'
      end

      it 'sends telemetry after the delay' do
        Timecop.freeze(DateTime.new(2020, 2, 22, 12, 12, 15))

        subject.count('test', 21)

        expect(socket.recv[0]).to eq_with_telemetry 'test:21|c'
      end
    end

    it 'handles all data type' do
      subject.increment('test', 1)
      expect(socket.recv[0]).to eq_with_telemetry('test:1|c', metrics: 1, packets_sent: 0, bytes_sent: 0)

      subject.decrement('test', 1)
      expect(socket.recv[0]).to eq_with_telemetry('test:-1|c', metrics: 1, packets_sent: 1, bytes_sent: 680)

      subject.count('test', 21)
      expect(socket.recv[0]).to eq_with_telemetry('test:21|c', metrics: 1, packets_sent: 1, bytes_sent: 683)

      subject.gauge('test', 21)
      expect(socket.recv[0]).to eq_with_telemetry('test:21|g', metrics: 1, packets_sent: 1, bytes_sent: 683)

      subject.histogram('test', 21)
      expect(socket.recv[0]).to eq_with_telemetry('test:21|h', metrics: 1, packets_sent: 1, bytes_sent: 683)

      subject.timing('test', 21)
      expect(socket.recv[0]).to eq_with_telemetry('test:21|ms', metrics: 1, packets_sent: 1, bytes_sent: 683)

      subject.set('test', 21)
      expect(socket.recv[0]).to eq_with_telemetry('test:21|s', metrics: 1, packets_sent: 1, bytes_sent: 684)

      subject.service_check('sc', 0)
      expect(socket.recv[0]).to eq_with_telemetry('_sc|sc|0', metrics: 0, service_checks: 1, packets_sent: 1, bytes_sent: 683)

      subject.event('ev', 'text')
      expect(socket.recv[0]).to eq_with_telemetry('_e{2,4}:ev|text', metrics: 0, events: 1, packets_sent: 1, bytes_sent: 682)
    end

    context 'when batching' do
      # HACK: this test breaks encapsulation
      before do
        def subject.telemetry
          @telemetry
        end
      end

      it 'handles all data types' do
        subject.batch do |s|
          s.increment('test', 1)
          s.decrement('test', 1)
          s.count('test', 21)
          s.gauge('test', 21)
          s.histogram('test', 21)
          s.timing('test', 21)
          s.set('test', 21)
          s.service_check('sc', 0)
          s.event('ev', 'text')
        end

        expect(socket.recv[0]).to eq_with_telemetry("test:1|c\ntest:-1|c\ntest:21|c\ntest:21|g\ntest:21|h\ntest:21|ms\ntest:21|s\n_sc|sc|0\n_e{2,4}:ev|text",
          metrics: 7,
          service_checks: 1,
          events: 1
        )

        expect(subject.telemetry.flush).to eq_with_telemetry('', metrics: 0, service_checks: 0, events: 0, packets_sent: 1, bytes_sent: 766)
      end
    end

    context 'when some data is dropped' do
      let(:socket) do
        FakeUDPSocket.new.tap do |s|
          s.error_on_send('some error')
        end
      end

      # HACK: this test breaks encapsulation
      before do
        def subject.telemetry
          @telemetry
        end
      end

      it 'handles dropped data' do
        subject.gauge('test', 21)
        expect(subject.telemetry.flush).to eq_with_telemetry('', metrics: 1, service_checks: 0, events: 0, packets_dropped: 1, bytes_dropped: 681)
        subject.gauge('test', 21)
        expect(subject.telemetry.flush).to eq_with_telemetry('', metrics: 2, service_checks: 0, events: 0, packets_dropped: 2, bytes_dropped: 1364)

        #disable network failure
        socket.error_on_send(nil)

        subject.gauge('test', 21)
        expect(socket.recv[0]).to eq_with_telemetry('test:21|g', metrics: 3, service_checks: 0, events: 0, packets_dropped: 2, bytes_dropped: 1364)

        expect(subject.telemetry.flush).to eq_with_telemetry('', metrics: 0, service_checks: 0, events: 0, packets_sent: 1, bytes_sent: 684)
      end
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

      expect(socket.recv[0]).to eq_with_telemetry('yolo:1|c')
    end

    it 'accepts a class name as a stat name' do
      subject.increment(Object)

      expect(socket.recv[0]).to eq_with_telemetry('Object:1|c')
    end

    it 'replaces Ruby constants delimeter with graphite package name' do
      class Datadog::Statsd::SomeClass; end
      subject.increment(Datadog::Statsd::SomeClass)

      expect(socket.recv[0]).to eq_with_telemetry 'Datadog.Statsd.SomeClass:1|c'
    end

    it 'replaces statsd reserved chars in the stat name' do
      subject.increment('ray@hostname.blah|blah.blah:blah')
      expect(socket.recv[0]).to eq_with_telemetry 'ray_hostname.blah_blah.blah_blah:1|c'
    end

    it 'works with frozen strings' do
      subject.increment('some-stat'.freeze)

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
      expect(socket.recv[0]).to eq_with_telemetry 'stat:1|c|#name:foobarfoo'
    end

    it 'handles the cases when some tags are frozen strings' do
      subject.increment('stat', tags: ['first_tag'.freeze, 'second_tag'])
    end

    it 'converts all values to strings' do
      tag = double('a tag', to_s: 'yolo')

      subject.increment('stat', tags: [tag])
      expect(socket.recv[0]).to eq_with_telemetry 'stat:1|c|#yolo'
    end
  end

  # TODO: This specs will have to move to another class (a responsibility that we will have to separate)
  describe 'handling socket errors' do
    let(:namespace) { nil }
    let(:sample_rate) { nil }
    let(:tags) { nil }

    before do
      allow(socket).to receive(:send).and_raise(SocketError)
    end

    it 'ignores socket errors' do
      expect(subject.increment('foobar')).to be_nil
    end

    it 'logs socket errors' do
      subject.increment('foobar')
      expect(log.string).to match 'Statsd: SocketError'
    end

    context 'when there is no loggers' do
      let(:logger) { nil }

      it 'does not fail' do
        subject.increment('foobar')
      end
    end
  end

  # TODO: This specs will have to move to another class (a responsibility that we will have to separate)
  # HACK: those tests are breaking encapsulation
  describe 'handling closed sockets', pending: true do
    it 'tries to reconnect once' do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).returns('YEP') # 2nd call
      socket.expects(:send).raises(IOError.new('closed stream')) # first call

      @statsd.increment('foobar')
    end

    it 'ignores and logs if it fails to reconnect' do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).raises(RuntimeError) # 2nd call
      socket.expects(:send).raises(IOError.new('closed stream')) # first call

      assert_nil @statsd.increment('foobar')
      _(@log.string).must_include 'Statsd: RuntimeError'
    end

    it 'ignores and logs errors while trying to reconnect' do
      socket.expects(:send).raises(IOError.new('closed stream'))
      @statsd.connection.expects(:connect).raises(SocketError)

      assert_nil @statsd.increment('foobar')
      _(@log.string).must_include 'Statsd: SocketError'
    end
  end

  # TODO: This specs will have to move to another class (a responsibility that we will have to separate)
  # HACK: those tests are breaking encapsulation
  describe 'handling not connected socket', pending: true do
    it 'tries to reconnect once' do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).returns('YEP') # 2nd call
      socket.expects(:send).raises(Errno::ENOTCONN.new('closed stream')) # first call

      @statsd.increment('foobar')
    end

    it 'ignores and logs if it fails to reconnect' do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).raises(RuntimeError) # 2nd call
      socket.expects(:send).raises(Errno::ENOTCONN.new) # first call

      assert_nil @statsd.increment('foobar')
      _(@log.string).must_include 'Statsd: RuntimeError'
    end

    it 'ignores and logs errors while trying to reconnect' do
      socket.expects(:send).raises(Errno::ENOTCONN.new)
      @statsd.connection.expects(:connect).raises(SocketError)

      assert_nil @statsd.increment('foobar')
      _(@log.string).must_include 'Statsd: SocketError'
    end
  end

  # TODO: This specs will have to move to another class (a responsibility that we will have to separate)
  # HACK: those tests are breaking encapsulation
  describe 'handling connection refused', pending: true do
    it 'tries to reconnect once' do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).returns('YEP') # 2nd call
      socket.expects(:send).raises(Errno::ECONNREFUSED.new('closed stream')) # first call

      @statsd.increment('foobar')
    end

    it 'ignores and logs if it fails to reconnect' do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).raises(RuntimeError) # 2nd call
      socket.expects(:send).raises(Errno::ECONNREFUSED.new) # first call

      assert_nil @statsd.increment('foobar')
      _(@log.string).must_include 'Statsd: RuntimeError'
    end

    it 'ignores and logs errors while trying to reconnect' do
      socket.expects(:send).raises(Errno::ECONNREFUSED.new)
      @statsd.connection.expects(:connect).raises(SocketError)

      assert_nil @statsd.increment('foobar')
      _(@log.string).must_include 'Statsd: SocketError'
    end
  end

  # TODO: This specs will have to move to another class (a responsibility that we will have to separate)
  # HACK: those tests are breaking encapsulation
  describe 'UDS error handling', pending: true do
    subject do
      described_class.new('localhost', 1234,
        socket_path: '/tmp/socket',
        disable_telemetry: true
      )
    end

    describe 'when socket throws connection reset error' do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise Errno::ECONNRESET }

        @fake_socket2 = Minitest::Mock.new
        @fake_socket2.expect(:connect, true) { true }
        @fake_socket2.expect :sendmsg_nonblock, true, ['bar:1|c']
      end

      it 'should ignore message and try reconnect on next call' do
        Socket.stub(:new, @fake_socket) do
          @statsd.increment('foo')
        end
        @statsd.increment('baz')
        Socket.stub(:new, @fake_socket2) do
          @statsd.increment('bar')
        end
        @fake_socket.verify
        @fake_socket2.verify
      end
    end

    describe 'when socket throws connection refused error' do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise Errno::ECONNREFUSED }

        @fake_socket2 = Minitest::Mock.new
        @fake_socket2.expect(:connect, true) { true }
        @fake_socket2.expect :sendmsg_nonblock, true, ['bar:1|c']
      end

      it 'should ignore message and try reconnect on next call' do
        Socket.stub(:new, @fake_socket) do
          @statsd.increment('foo')
        end
        @statsd.increment('baz')
        Socket.stub(:new, @fake_socket2) do
          @statsd.increment('bar')
        end
        @fake_socket.verify
        @fake_socket2.verify
      end
    end

    describe 'when socket throws file not found error' do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise Errno::ENOENT }

        @fake_socket2 = Minitest::Mock.new
        @fake_socket2.expect(:connect, true) { true }
        @fake_socket2.expect :sendmsg_nonblock, true, ['bar:1|c']
      end

      it 'should ignore message and try reconnect on next call' do
        Socket.stub(:new, @fake_socket) do
          @statsd.increment('foo')
        end
        @statsd.increment('baz')
        Socket.stub(:new, @fake_socket2) do
          @statsd.increment('bar')
        end
        @fake_socket.verify
        @fake_socket2.verify
      end
    end

    describe 'when socket is full' do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise IO::EAGAINWaitWritable }
        @fake_socket.expect :sendmsg_nonblock, true, ['bar:1|c']

        @fake_socket2 = Minitest::Mock.new
      end

      it 'should ignore message but does not reconnect on next call' do
        Socket.stub(:new, @fake_socket) do
          @statsd.increment('foo')
        end
        @statsd.increment('baz')
        Socket.stub(:new, @fake_socket2) do
          @statsd.increment('bar')
        end
        @fake_socket.verify
        @fake_socket2.verify
      end
    end
  end
end