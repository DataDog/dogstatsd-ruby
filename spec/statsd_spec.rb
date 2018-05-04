require_relative 'helper'
require 'socket'
require 'stringio'
require 'mocha/minitest'

SingleCov.covered! file: 'lib/datadog/statsd.rb' if RUBY_VERSION > "2.0"

describe Datadog::Statsd do
  class Datadog::Statsd
    # we need to stub this
    attr_accessor :socket
  end

  before do
    @statsd = Datadog::Statsd.new('localhost', 1234)
    @statsd.socket = FakeUDPSocket.new
  end

  describe ".VERSION" do
    it "has a version" do
      Datadog::Statsd.VERSION.must_match(/^\d+\.\d+\.\d+/)
    end
  end

  describe '.current' do
    before { Datadog::Statsd.current = nil }

    it 'returns a default instance' do
      Datadog::Statsd.current.must_be_instance_of(Datadog::Statsd)
      Datadog::Statsd.current.host.must_equal(Datadog::Statsd::DEFAULT_HOST)
      Datadog::Statsd.current.port.must_equal(Datadog::Statsd::DEFAULT_PORT)
    end

    it 'honors the provided arguments' do
      Datadog::Statsd.current('sample.lvh.me', port = 1515)
      Datadog::Statsd.current.host.must_equal('sample.lvh.me')
      Datadog::Statsd.current.port.must_equal(1515)
    end
  end

  describe '.current=' do
    let(:client) { Datadog::Statsd.new(host = 'real.lvh.me', port = 4711) }

    it 'uses the provided instance' do
      Datadog::Statsd.current = client
      Datadog::Statsd.current.host.must_equal('real.lvh.me')
      Datadog::Statsd.current.port.must_equal(4711)
    end
  end

  describe "#initialize" do
    it "should set the host and port" do
      @statsd.host.must_equal 'localhost'
      @statsd.port.must_equal 1234
    end

    it "should create a UDPSocket when nothing is given" do
      statsd = Datadog::Statsd.new
      statsd.socket.must_be_instance_of(UDPSocket)
    end

    it "should create a UDPSocket when host and port are given" do
      statsd = Datadog::Statsd.new('localhost', 1234)
      statsd.socket.must_be_instance_of(UDPSocket)
    end

    it "should not create a socket when socket_path is given" do
      # the socket may not exist when creating the Statsd object
      statsd = Datadog::Statsd.new('localhost', 1234, {socket_path: '/tmp/socket'})
      assert_nil statsd.socket
    end

    it "should default the host to 127.0.0.1, port to 8125, namespace to nil, and tags to []" do
      statsd = Datadog::Statsd.new
      statsd.host.must_equal '127.0.0.1'
      statsd.port.must_equal 8125
      assert_nil statsd.namespace
      statsd.tags.must_equal []
    end

    it 'should be able to set host, port, namespace, and global tags' do
      statsd = Datadog::Statsd.new '1.3.3.7', 8126, :tags => %w(global), :namespace => 'space'
      statsd.host.must_equal '1.3.3.7'
      statsd.port.must_equal 8126
      statsd.namespace.must_equal 'space'
      statsd.instance_variable_get('@prefix').must_equal 'space.'
      statsd.tags.must_equal ['global']
    end
  end

  describe "writers" do
    it "should set host, port, namespace, and global tags" do
      @statsd.host = '1.2.3.4'
      @statsd.port = 5678
      @statsd.namespace = 'n4m35p4c3'
      @statsd.tags = ['t4g5']

      @statsd.host.must_equal '1.2.3.4'
      @statsd.port.must_equal 5678
      @statsd.namespace.must_equal 'n4m35p4c3'
      @statsd.tags.must_equal ['t4g5']
    end

    it "should not resolve hostnames to IPs" do
      @statsd.host = 'localhost'
      @statsd.host.must_equal 'localhost'
    end

    it "should set nil host to default" do
      @statsd.host = nil
      @statsd.host.must_equal '127.0.0.1'
    end

    it "should set nil port to default" do
      @statsd.port = nil
      @statsd.port.must_equal 8125
    end

    it 'should set prefix to nil when namespace is set to nil' do
      @statsd.namespace = nil
      assert_nil @statsd.namespace
      assert_nil @statsd.instance_variable_get('@prefix')
    end

    it 'should set nil tags to default' do
      @statsd.tags = nil
      @statsd.tags.must_equal []
    end

    it 'should reject non-array tags' do
      lambda { @statsd.tags = 'tsdfs' }.must_raise ArgumentError
    end

    it 'ignore nil tags' do
      @statsd.tags = ['tag1', nil, 'tag2']
      @statsd.tags.must_equal %w[tag1 tag2]
    end

    it 'converts symbols to strings' do
      @statsd.tags = [:tag1, :tag2]
      @statsd.tags.must_equal %w[tag1 tag2]
    end

    it 'assigns regular tags' do
      tags = %w[tag1 tag2]
      @statsd.tags = tags
      @statsd.tags.must_equal tags
    end
  end

  describe "#increment" do
    it "should format the message according to the statsd spec" do
      @statsd.increment('foobar')
      @statsd.socket.recv.must_equal ['foobar:1|c']
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.increment('foobar', :sample_rate=>0.5)
        @statsd.socket.recv.must_equal ['foobar:1|c|@0.5']
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.increment('foobar', 0.5)
        @statsd.socket.recv.must_equal ['foobar:1|c|@0.5']
      end
    end

    describe "with a increment by" do
      it "should increment by the number given" do
        @statsd.increment('foobar', :by=>5)
        @statsd.socket.recv.must_equal ['foobar:5|c']
      end
    end
  end

  describe "#decrement" do
    it "should format the message according to the statsd spec" do
      @statsd.decrement('foobar')
      @statsd.socket.recv.must_equal ['foobar:-1|c']
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.decrement('foobar', :sample_rate => 0.5)
        @statsd.socket.recv.must_equal ['foobar:-1|c|@0.5']
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.decrement('foobar', 0.5)
        @statsd.socket.recv.must_equal ['foobar:-1|c|@0.5']
      end
    end

    describe "with a decrement by" do
      it "should decrement by the number given" do
        @statsd.decrement('foobar', :by=>5)
        @statsd.socket.recv.must_equal ['foobar:-5|c']
      end
    end
  end

  describe "#gauge" do
    it "should send a message with a 'g' type, per the nearby fork" do
      @statsd.gauge('begrutten-suffusion', 536)
      @statsd.socket.recv.must_equal ['begrutten-suffusion:536|g']
      @statsd.gauge('begrutten-suffusion', -107.3)
      @statsd.socket.recv.must_equal ['begrutten-suffusion:-107.3|g']
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.gauge('begrutten-suffusion', 536, :sample_rate=>0.1)
        @statsd.socket.recv.must_equal ['begrutten-suffusion:536|g|@0.1']
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.gauge('begrutten-suffusion', 536, 0.1)
        @statsd.socket.recv.must_equal ['begrutten-suffusion:536|g|@0.1']
      end
    end
  end

  describe "#histogram" do
    it "should send a message with a 'h' type, per the nearby fork" do
      @statsd.histogram('ohmy', 536)
      @statsd.socket.recv.must_equal ['ohmy:536|h']
      @statsd.histogram('ohmy', -107.3)
      @statsd.socket.recv.must_equal ['ohmy:-107.3|h']
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.gauge('begrutten-suffusion', 536, :sample_rate=>0.1)
        @statsd.socket.recv.must_equal ['begrutten-suffusion:536|g|@0.1']
      end
    end
  end

  describe "#set" do
    it "should send a message with a 's' type, per the nearby fork" do
      @statsd.set('my.set', 536)
      @statsd.socket.recv.must_equal ['my.set:536|s']
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should send a message with a 's' type, per the nearby fork" do
        @statsd.set('my.set', 536, :sample_rate=>0.5)
        @statsd.socket.recv.must_equal ['my.set:536|s|@0.5']
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should send a message with a 's' type, per the nearby fork" do
        @statsd.set('my.set', 536, 0.5)
        @statsd.socket.recv.must_equal ['my.set:536|s|@0.5']
      end
    end
  end

  describe "#timing" do
    it "should format the message according to the statsd spec" do
      @statsd.timing('foobar', 500)
      @statsd.socket.recv.must_equal ['foobar:500|ms']
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.timing('foobar', 500, :sample_rate=>0.5)
        @statsd.socket.recv.must_equal ['foobar:500|ms|@0.5']
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.timing('foobar', 500, 0.5)
        @statsd.socket.recv.must_equal ['foobar:500|ms|@0.5']
      end
    end
  end

  describe "#time" do
    describe "With actual time testing" do
      before do
        stub_time 0 # Freezing time to prevent random test failures
      end

      it "should format the message according to the statsd spec" do
        @statsd.time('foobar') do
          stub_time 1
        end
        @statsd.socket.recv.must_equal ['foobar:1000|ms']
      end

      it "should still time if block is failing" do
        @statsd.time('foobar') do
          stub_time 1
          raise StandardError, 'This is failing'
        end rescue
        @statsd.socket.recv.must_equal ['foobar:1000|ms']
      end

      def helper_time_return
        @statsd.time('foobar') do
          stub_time 1
          return
        end
      end

      it "should still time if block `return`s" do
        helper_time_return
        @statsd.socket.recv.must_equal ['foobar:1000|ms']
      end
    end

    it "should return the result of the block" do
      result = @statsd.time('foobar') { 'test' }
      result.must_equal 'test'
    end

    it "should reraise the error if block is failing" do
      assert_raises StandardError do
        @statsd.time('foobar') { raise StandardError, 'This is failing' }
      end
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        stub_time 0
        @statsd.time('foobar', :sample_rate=>0.5) do
          stub_time 1
        end
        @statsd.socket.recv.must_equal ['foobar:1000|ms|@0.5']
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        stub_time 0
        @statsd.time('foobar', 0.5) do
          stub_time 1
        end
        @statsd.socket.recv.must_equal ['foobar:1000|ms|@0.5']
      end
    end
  end

  describe "#sampled" do
    describe "when the sample rate is 1" do
      before { class << @statsd; def rand; raise end; end }
      it "should send" do
        @statsd.timing('foobar', 500, :sample_rate=>1)
        @statsd.socket.recv.must_equal ['foobar:500|ms']
      end
    end

    describe "when the sample rate is greater than a random value [0,1]" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should send" do
        @statsd.timing('foobar', 500, :sample_rate=>0.5)
        @statsd.socket.recv.must_equal ['foobar:500|ms|@0.5']
      end
    end

    describe "when the sample rate is less than a random value [0,1]" do
      before { class << @statsd; def rand; 1; end; end } # ensure no delivery
      it "should not send" do
        assert_nil @statsd.timing('foobar', 500, :sample_rate=>0.5)
      end
    end

    describe "when the sample rate is equal to a random value [0,1]" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should send" do
        @statsd.timing('foobar', 500, :sample_rate=>0.5)
        @statsd.socket.recv.must_equal ['foobar:500|ms|@0.5']
      end
    end
  end

  describe "#distribution" do
    it "send a message with d type" do
      @statsd.distribution('begrutten-suffusion', 536)
      @statsd.socket.recv.must_equal ['begrutten-suffusion:536|d']
    end
  end

  describe "with namespace" do
    before { @statsd.namespace = 'service' }

    it "should add namespace to increment" do
      @statsd.increment('foobar')
      @statsd.socket.recv.must_equal ['service.foobar:1|c']
    end

    it "should add namespace to decrement" do
      @statsd.decrement('foobar')
      @statsd.socket.recv.must_equal ['service.foobar:-1|c']
    end

    it "should add namespace to timing" do
      @statsd.timing('foobar', 500)
      @statsd.socket.recv.must_equal ['service.foobar:500|ms']
    end

    it "should add namespace to gauge" do
      @statsd.gauge('foobar', 500)
      @statsd.socket.recv.must_equal ['service.foobar:500|g']
    end
  end

  describe "with logging" do
    require 'stringio'
    before { Datadog::Statsd.logger = Logger.new(@log = StringIO.new)}

    it "should write to the log in debug" do
      Datadog::Statsd.logger.level = Logger::DEBUG

      @statsd.increment('foobar')

      @log.string.must_match "Statsd: foobar:1|c"
    end

    it "should not write to the log unless debug" do
      Datadog::Statsd.logger.level = Logger::INFO

      @statsd.increment('foobar')

      @log.string.must_be_empty
    end
  end

  describe "stat names" do
    it "should accept anything as stat" do
      @statsd.increment(Object)
    end

    it "should replace ruby constant delimeter with graphite package name" do
      class Datadog::Statsd::SomeClass; end
      @statsd.increment(Datadog::Statsd::SomeClass, :sample_rate=>1)

      @statsd.socket.recv.must_equal ['Datadog.Statsd.SomeClass:1|c']
    end

    it "should replace statsd reserved chars in the stat name" do
      @statsd.increment('ray@hostname.blah|blah.blah:blah')
      @statsd.socket.recv.must_equal ['ray_hostname.blah_blah.blah_blah:1|c']
    end

    it "should handle frozen strings" do
      @statsd.increment("some-stat".freeze)
    end
  end

  describe "tag names" do
    it "replaces reserved chars for tags" do
      @statsd.increment('stat', tags: ["name:foo,bar|foo"])
      @statsd.socket.recv.must_equal ['stat:1|c|#name:foobarfoo']
    end

    it "handles the cases when some tags are frozen strings" do
      @statsd.increment('stat', tags: ["first_tag".freeze, "second_tag"])
    end

    it "converts all values to strings" do
      @statsd.increment('stat', tags: [:sample_tag])
      @statsd.socket.recv.must_equal ['stat:1|c|#sample_tag']
    end
  end

  describe "handling socket errors" do
    before do
      Datadog::Statsd.logger = Logger.new(@log = StringIO.new)
      @statsd.socket.instance_eval { def send(*) raise SocketError end }
    end

    it "should ignore socket errors" do
      assert_nil @statsd.increment('foobar')
    end

    it "should log socket errors" do
      @statsd.increment('foobar')
      @log.string.must_match 'Statsd: SocketError'
    end
  end

  describe "handling closed socket" do
    before do
      Datadog::Statsd.logger = Logger.new(@log = StringIO.new)
    end

    it "should try once to reconnect" do
      @statsd.socket.instance_eval do
        def send_calls() @send_calls ; end

        def send(*args)
          @send_calls ||= 0
          @send_calls += 1
          raise IOError.new("closed stream") unless @send_calls > 1
          super(*args)
        end
      end
      @statsd.instance_eval { def connect_to_socket(*) @socket ; end }

      @statsd.increment('foobar')

      @statsd.socket.send_calls.must_equal 2
      @statsd.socket.recv.must_equal ["foobar:1|c"]
    end

    it "should ignore and log if it fails to reconnect" do
      @statsd.socket.instance_eval do
        def send_calls() @send_calls ; end

        def send(*)
          @send_calls ||= 0
          @send_calls += 1
          raise IOError.new("closed stream")
        end
      end
      @statsd.instance_eval { def connect_to_socket(*) @socket ; end }

      assert_nil @statsd.increment('foobar')
      @statsd.socket.send_calls.must_equal 2
      @log.string.must_match 'Statsd: IOError closed stream'
    end

    it "should ignore and log errors while trying to reconnect" do
      @statsd.socket.instance_eval { def send(*) raise IOError.new("closed stream") end }
      @statsd.instance_eval { def connect_to_socket(*) raise SocketError end }

      assert_nil @statsd.increment('foobar')
      @log.string.must_match 'Statsd: SocketError'
    end
  end

  describe "UDS error handling" do
    before do
      @statsd = Datadog::Statsd.new('localhost', 1234, {:socket_path => '/tmp/socket'})
      Datadog::Statsd.logger = Logger.new(@log = StringIO.new)
    end

    describe "when socket throws connection reset error" do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise Errno::ECONNRESET }

        @fake_socket2 = Minitest::Mock.new
        @fake_socket2.expect(:connect, true) { true }
        @fake_socket2.expect :sendmsg_nonblock, true, ['bar:1|c']
      end

      it "should ignore message and try reconnect on next call" do
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

    describe "when socket throws connection refused error" do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise Errno::ECONNREFUSED }

        @fake_socket2 = Minitest::Mock.new
        @fake_socket2.expect(:connect, true) { true }
        @fake_socket2.expect :sendmsg_nonblock, true, ['bar:1|c']
      end

      it "should ignore message and try reconnect on next call" do
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

    describe "when socket throws file not found error" do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise Errno::ENOENT }

        @fake_socket2 = Minitest::Mock.new
        @fake_socket2.expect(:connect, true) { true }
        @fake_socket2.expect :sendmsg_nonblock, true, ['bar:1|c']
      end

      it "should ignore message and try reconnect on next call" do
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

    describe "when socket is full" do
      before do
        @fake_socket = Minitest::Mock.new
        @fake_socket.expect(:connect, true) { true }
        @fake_socket.expect :sendmsg_nonblock, true, ['foo:1|c']
        @fake_socket.expect(:sendmsg_nonblock, true) { raise IO::EAGAINWaitWritable }
        @fake_socket.expect :sendmsg_nonblock, true, ['bar:1|c']

        @fake_socket2 = Minitest::Mock.new
      end

      it "should ignore message but does not reconnect on next call" do
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

  describe "tagged" do

    it "gauges support tags" do
      @statsd.gauge("gauge", 1, :tags=>%w(country:usa state:ny))
      @statsd.socket.recv.must_equal ['gauge:1|g|#country:usa,state:ny']
    end

    it "counters support tags" do
      @statsd.increment("c", :tags=>%w(country:usa other))
      @statsd.socket.recv.must_equal ['c:1|c|#country:usa,other']

      @statsd.decrement("c", :tags=>%w(country:china))
      @statsd.socket.recv.must_equal ['c:-1|c|#country:china']

      @statsd.count("c", 100, :tags=>%w(country:finland))
      @statsd.socket.recv.must_equal ['c:100|c|#country:finland']
    end

    it "timing support tags" do
      @statsd.timing("t", 200, :tags=>%w(country:canada other))
      @statsd.socket.recv.must_equal ['t:200|ms|#country:canada,other']

      @statsd.time('foobar', :tags => ["123"]) { sleep(0.001); 'test' }
    end

    it "global tags setter" do
      @statsd.tags = %w(country:usa other)
      @statsd.increment("c")
      @statsd.socket.recv.must_equal ['c:1|c|#country:usa,other']
    end

    it "global tags setter and regular tags" do
      @statsd.tags = %w(country:usa other)
      @statsd.increment("c", :tags=>%w(somethingelse))
      @statsd.socket.recv.must_equal ['c:1|c|#country:usa,other,somethingelse']
    end

    it "nil global tags" do
      @statsd.tags = nil
      @statsd.increment("c")
      @statsd.socket.recv.must_equal ['c:1|c']
    end
  end

  describe "batched" do

    it "should not send anything when the buffer is empty" do
      @statsd.batch { }
      assert_nil @statsd.socket.recv
    end

    it "should allow to send single sample in one packet" do
      @statsd.batch do |s|
        s.increment("mycounter")
      end
      @statsd.socket.recv.must_equal ['mycounter:1|c']
    end

    it "should allow to send multiple sample in one packet" do
      @statsd.batch do |s|
        s.increment("mycounter")
        s.decrement("myothercounter")
      end
      @statsd.socket.recv.must_equal ["mycounter:1|c\nmyothercounter:-1|c"]
    end

    it "should default back to single metric packet after the block" do
      @statsd.batch do |s|
        s.gauge("mygauge", 10)
        s.gauge("myothergauge", 20)
      end
      @statsd.increment("mycounter")
      @statsd.increment("myothercounter")
      @statsd.socket.recv.must_equal ["mygauge:10|g\nmyothergauge:20|g"]
      @statsd.socket.recv.must_equal ['mycounter:1|c']
      @statsd.socket.recv.must_equal ['myothercounter:1|c']
    end

    it "should flush when the buffer gets too big" do
      @statsd.batch do |s|
        # increment a counter 50 times in batch
        51.times do
          s.increment("mycounter")
        end

        # We should receive a packet of 50 messages that was automatically
        # flushed when the buffer got too big
        theoretical_reply = Array.new
        50.times do
          theoretical_reply.push('mycounter:1|c')
        end
        @statsd.socket.recv.must_equal [theoretical_reply.join("\n")]
      end

      # When the block finishes, the remaining buffer is flushed
      @statsd.socket.recv.must_equal ['mycounter:1|c']
    end

    it "should batch nested batch blocks" do
      @statsd.batch do
        @statsd.increment("level-1")
        @statsd.batch do
          @statsd.increment("level-2")
        end
        @statsd.increment("level-1-again")
      end
      # all three should be sent in a single batch when the outer block finishes
      @statsd.socket.recv.must_equal ["level-1:1|c\nlevel-2:1|c\nlevel-1-again:1|c"]
      # we should revert back to sending single metric packets
      @statsd.increment("outside")
      @statsd.socket.recv.must_equal ["outside:1|c"]
    end
  end

  describe "#event" do
    10.times do
      title = Faker::Lorem.sentence(_word_count =  rand(3))
      text = Faker::Lorem.sentence(_word_count = rand(3))
      tags = Faker::Lorem.words(rand(1..10))
      tags_joined = tags.join(",")

      it "Only title and text" do
        @statsd.event(title, text)
        @statsd.socket.recv.must_equal [@statsd.format_event(title, text)]
      end
      it "With line break in Text and title" do
        title_break_line = "#{title} \n second line"
        text_break_line = "#{text} \n second line"
        @statsd.event(title_break_line, text_break_line)
        @statsd.socket.recv.must_equal [@statsd.format_event(title_break_line, text_break_line)]
      end
      it "Event data string too long > 8KB" do
        long_text = "#{text} " * 200000
        proc {@statsd.event(title, long_text)}.must_raise RuntimeError
      end
      it "With known alert_type" do
        @statsd.event(title, text, :alert_type => 'warning')
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|t:warning"]
      end
      it "With unknown alert_type" do
        @statsd.event(title, text, :alert_type => 'bizarre')
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|t:bizarre"]
      end
      it "With known priority" do
        @statsd.event(title, text, :priority => 'low')
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|p:low"]
      end
      it "With unknown priority" do
        @statsd.event(title, text, :priority => 'bizarre')
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|p:bizarre"]
      end
      it "With hostname" do
        @statsd.event(title, text, :hostname => 'hostname_test')
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|h:hostname_test"]
      end
      it "With aggregation_key" do
        @statsd.event(title, text, :aggregation_key => 'aggkey 1')
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|k:aggkey 1"]
      end
      it "With source_type_name" do
        @statsd.event(title, text, :source_type_name => 'source 1')
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|s:source 1"]
      end
      it "With several tags" do
        @statsd.event(title, text, :tags => tags)
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text)}|##{tags_joined}"]
      end
      it "Takes into account the common tags" do
        basic_result = @statsd.format_event(title, text)
        common_tag = 'common'
        @statsd.instance_variable_set :@tags, [common_tag]
        @statsd.event(title, text)
        @statsd.socket.recv.must_equal ["#{basic_result}|##{common_tag}"]
      end
      it "combines common and specific tags" do
        basic_result = @statsd.format_event(title, text)
        common_tag = 'common'
        @statsd.instance_variable_set :@tags, [common_tag]
        @statsd.event(title, text, :tags => tags)
        @statsd.socket.recv.must_equal ["#{basic_result}|##{common_tag},#{tags_joined}"]
      end
      it "With alert_type, priority, hostname, several tags" do
        @statsd.event(title, text, :alert_type => 'warning', :priority => 'low', :hostname => 'hostname_test', :tags => tags)
        opts = {
          :alert_type => 'warning',
          :priority => 'low',
          :hostname => 'hostname_test',
          :tags => tags
        }
        @statsd.socket.recv.must_equal ["#{@statsd.format_event(title, text, opts)}"]
      end
    end
  end

  describe "#service_check" do
    10.times do
      name = Faker::Lorem.sentence(_word_count = rand(3))
      status = rand(4)
      hostname = "hostname_test"
      tags = Faker::Lorem.words(rand(1..10))
      tags_joined = tags.join(",")

      it "Only name and status" do
        @statsd.service_check(name, status)
        @statsd.socket.recv.must_equal [@statsd.format_service_check(name, status)]
      end

      it "With hostname" do
        @statsd.service_check(name, status, :hostname => hostname)
        @statsd.socket.recv.must_equal ["_sc|#{name}|#{status}|h:#{hostname}"]
      end

      it "With message" do
        @statsd.service_check(name, status, :message => 'testing | m: \n')
        @statsd.socket.recv.must_equal ["_sc|#{name}|#{status}|m:testing  m\\: \\n"]
      end

      it "With tags" do
        @statsd.service_check(name, status, :tags => tags)
        @statsd.socket.recv.must_equal ["_sc|#{name}|#{status}|##{tags_joined}"]
      end

      it "With hostname, message, and tags" do
        @statsd.service_check(name, status, :message => 'testing | m: \n', :hostname => 'hostname_test',
                              :tags => tags)
        @statsd.socket.recv.must_equal ["_sc|#{name}|#{status}|h:#{hostname}|##{tags_joined}|m:testing  m\\: \\n"]
      end
    end
  end

  describe "#close" do
    it "closes the socket" do
      socket = MiniTest::Mock.new
      socket.expect :close, nil
      @statsd.socket = socket
      @statsd.close
    end
  end

  def stub_time(shift)
    t = 12345.0 + shift
    if RUBY_VERSION >= "2.1.0"
      Process.stubs(:clock_gettime).returns(t)
    else
      Time.stubs(:now).returns(Time.at(t))
    end
  end
end

describe Datadog::Statsd do
  describe "with a real UDP socket" do
    it "should actually send stuff over the socket" do
      socket = UDPSocket.new
      host, port = 'localhost', 12345
      socket.bind(host, port)

      statsd = Datadog::Statsd.new(host, port)
      statsd.increment('foobar')
      message = socket.recvfrom(16).first
      message.must_equal 'foobar:1|c'
    end
  end
end if ENV['LIVE']
