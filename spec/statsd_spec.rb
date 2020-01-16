# frozen_string_literal: true
require_relative 'helper'
require 'allocation_stats' if RUBY_VERSION >= "2.3.0"
require 'socket'
require 'stringio'
require 'time'

SingleCov.covered! file: 'lib/datadog/statsd.rb' if RUBY_VERSION > "2.0"

describe Datadog::Statsd do
  class Datadog::Statsd
    # we need to stub this
    attr_accessor :socket
    # we need to be able to access this
    attr_accessor :telemetry
  end

  let(:namespace) { nil }
  let(:sample_rate) { nil }
  let(:socket) { FakeUDPSocket.new }

  before do
    @statsd = Datadog::Statsd.new('localhost', 1234, namespace: namespace, sample_rate: sample_rate)
    @statsd.connection.instance_variable_set(:@socket, socket)
  end

  describe "VERSION" do
    it "has a version" do
      Datadog::Statsd::VERSION.must_match(/^\d+\.\d+\.\d+/)
    end
  end

  describe "#initialize" do
    it "sets the host and port" do
      @statsd.connection.host.must_equal 'localhost'
      @statsd.connection.port.must_equal 1234
    end

    it "uses env vars host and port when nil is given" do
      stub = Proc.new do |arg|
        arg == 'DD_AGENT_HOST' ? 'myhost' : '1234'
      end
      ENV.stub :fetch, stub do
        @statsd = Datadog::Statsd.new(nil, nil, {})
        @statsd.connection.host.must_equal 'myhost'
        @statsd.connection.port.must_equal '1234'
      end
    end

    it "uses default host and port when nil is given to allow only passing options" do
      @statsd = Datadog::Statsd.new(nil, nil, {})
      @statsd.connection.host.must_equal '127.0.0.1'
      @statsd.connection.port.must_equal 8125
    end

    it "creates a UDPSocket when nothing is given" do
      statsd = Datadog::Statsd.new
      statsd.connection.send(:socket).must_be_instance_of(UDPSocket)
    end

    it "create a Socket when socket_path is given" do
      # the socket may not exist when creating the Statsd object
      statsd = Datadog::Statsd.new('localhost', 1234, {socket_path: '/tmp/socket'})
      assert_raises Errno::ENOENT do
        statsd.connection.send(:socket)
      end
    end

    it "defaults host, port, namespace, and tags" do
      statsd = Datadog::Statsd.new
      statsd.connection.host.must_equal '127.0.0.1'
      statsd.connection.port.must_equal 8125
      assert_nil statsd.namespace
      statsd.tags.must_equal []
    end

    it "defaults host, port, namespace, and tags contains entity id" do
      stub = Proc.new do |arg|
        arg == 'DD_ENTITY_ID' ? '04652bb7-19b7-11e9-9cc6-42010a9c016d' : nil
      end
      ENV.stub :fetch, stub do
        statsd = Datadog::Statsd.new
        statsd.connection.host.must_equal '127.0.0.1'
        statsd.connection.port.must_equal 8125
        assert_nil statsd.namespace
        statsd.tags.must_equal ['dd.internal.entity_id:04652bb7-19b7-11e9-9cc6-42010a9c016d']
      end
    end

    it 'sets host, port, namespace, and tags' do
      statsd = Datadog::Statsd.new '1.3.3.7', 8126, :tags => %w(global), :namespace => 'space'
      statsd.connection.host.must_equal '1.3.3.7'
      statsd.connection.port.must_equal 8126
      statsd.namespace.must_equal 'space'
      statsd.instance_variable_get('@prefix').must_equal 'space.'
      statsd.tags.must_equal ['global']
    end

    it 'sets host, port, namespace, and tags and get entity id from inv var' do
      stub = Proc.new do |arg|
        arg == 'DD_ENTITY_ID' ? '04652bb7-19b7-11e9-9cc6-42010a9c016d' : nil
      end
      ENV.stub :fetch, stub do
        statsd = Datadog::Statsd.new '1.3.3.7', 8126, :tags => %w(global), :namespace => 'space'
        statsd.connection.host.must_equal '1.3.3.7'
        statsd.connection.port.must_equal 8126
        statsd.namespace.must_equal 'space'
        statsd.instance_variable_get('@prefix').must_equal 'space.'
        statsd.tags.must_equal ['global', 'dd.internal.entity_id:04652bb7-19b7-11e9-9cc6-42010a9c016d']
      end
    end

    it 'fails on invalid tags' do
      assert_raises ArgumentError do
        Datadog::Statsd.new nil, nil, :tags => 'global'
      end
    end

    it "fails on unknown options" do
      assert_raises ArgumentError do
        Datadog::Statsd.new nil, nil, :foo => 'bar'
      end
    end

    it "accepts tags as a hash" do
      statsd = Datadog::Statsd.new '1.3.3.7', 8126, :tags => {one: "one", two: "two"}, :namespace => 'space'
      statsd.tags.must_equal ['one:one', 'two:two']
    end
  end

  describe "#open" do
    it "sends and then closes" do
      instance = nil
      Datadog::Statsd.open('1.2.3.4', 1234) do |s|
        instance = s
        s.connection.host.must_equal '1.2.3.4'
        s.increment 'foo'
        s.connection.expects(:close)
      end
      instance.class.must_equal Datadog::Statsd
    end

    it "does not fail closing when nothing was sent" do
      Datadog::Statsd.open('1.2.3.4', 1234) {}
    end
  end

  describe "#increment" do
    it "formats the message according to the statsd spec" do
      @statsd.increment('foobar')
      socket.recv[0].must equal_with_telemetry 'foobar:1|c'
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.increment('foobar', :sample_rate=>0.5)
        socket.recv[0].must equal_with_telemetry 'foobar:1|c|@0.5'
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.increment('foobar', 0.5)
        socket.recv[0].must equal_with_telemetry 'foobar:1|c|@0.5'
      end
    end

    describe "with a increment by" do
      it "should increment by the number given" do
        @statsd.increment('foobar', :by=>5)
        socket.recv[0].must equal_with_telemetry 'foobar:5|c'
      end
    end
  end

  describe "#decrement" do
    it "should format the message according to the statsd spec" do
      @statsd.decrement('foobar')
      socket.recv[0].must equal_with_telemetry 'foobar:-1|c'
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.decrement('foobar', :sample_rate => 0.5)
        socket.recv[0].must equal_with_telemetry 'foobar:-1|c|@0.5'
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.decrement('foobar', 0.5)
        socket.recv[0].must equal_with_telemetry 'foobar:-1|c|@0.5'
      end
    end

    describe "with a decrement by" do
      it "should decrement by the number given" do
        @statsd.decrement('foobar', :by=>5)
        socket.recv[0].must equal_with_telemetry 'foobar:-5|c'
      end
    end
  end

  describe "#count" do
    it "can set sample rate as 2nd argument" do
      @statsd.expects(:send_stats).with("foobar", 123, "c", sample_rate: 0.1)
      @statsd.count('foobar', 123, 0.1)
    end
  end

  describe "#gauge" do
    it "should send a message with a 'g' type, per the nearby fork" do
      @statsd.gauge('begrutten-suffusion', 536)
      socket.recv[0].must equal_with_telemetry 'begrutten-suffusion:536|g'

      @statsd.telemetry.reset
      @statsd.gauge('begrutten-suffusion', -107.3)
      socket.recv[0].must equal_with_telemetry 'begrutten-suffusion:-107.3|g'
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.gauge('begrutten-suffusion', 536, :sample_rate=>0.1)
        socket.recv[0].must equal_with_telemetry 'begrutten-suffusion:536|g|@0.1'
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.gauge('begrutten-suffusion', 536, 0.1)
        socket.recv[0].must equal_with_telemetry 'begrutten-suffusion:536|g|@0.1'
      end
    end
  end

  describe "#histogram" do
    it "should send a message with a 'h' type, per the nearby fork" do
      @statsd.histogram('ohmy', 536)
      socket.recv[0].must equal_with_telemetry 'ohmy:536|h'

      @statsd.telemetry.reset
      @statsd.histogram('ohmy', -107.3)
      socket.recv[0].must equal_with_telemetry 'ohmy:-107.3|h'
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.gauge('begrutten-suffusion', 536, :sample_rate=>0.1)
        socket.recv[0].must equal_with_telemetry 'begrutten-suffusion:536|g|@0.1'
      end
    end
  end

  describe "#set" do
    it "should send a message with a 's' type, per the nearby fork" do
      @statsd.set('my.set', 536)
      socket.recv[0].must equal_with_telemetry 'my.set:536|s'
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should send a message with a 's' type, per the nearby fork" do
        @statsd.set('my.set', 536, :sample_rate=>0.5)
        socket.recv[0].must equal_with_telemetry 'my.set:536|s|@0.5'
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should send a message with a 's' type, per the nearby fork" do
        @statsd.set('my.set', 536, 0.5)
        socket.recv[0].must equal_with_telemetry 'my.set:536|s|@0.5'
      end
    end
  end

  describe "#timing" do
    it "should format the message according to the statsd spec" do
      @statsd.timing('foobar', 500)
      socket.recv[0].must equal_with_telemetry 'foobar:500|ms'
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.timing('foobar', 500, :sample_rate=>0.5)
        socket.recv[0].must equal_with_telemetry 'foobar:500|ms|@0.5'
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @statsd.timing('foobar', 500, 0.5)
        socket.recv[0].must equal_with_telemetry 'foobar:500|ms|@0.5'
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
        socket.recv[0].must equal_with_telemetry 'foobar:1000|ms'
      end

      it "should still time if block is failing" do
        assert_raises StandardError do
          @statsd.time('foobar') do
            stub_time 1
            raise StandardError, 'This is failing'
          end
        end
        socket.recv[0].must equal_with_telemetry 'foobar:1000|ms'
      end

      def helper_time_return
        @statsd.time('foobar') do
          stub_time 1
          return
        end
      end

      it "should still time if block `return`s" do
        helper_time_return
        socket.recv[0].must equal_with_telemetry 'foobar:1000|ms'
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

    it "can run without PROCESS_TIME_SUPPORTED" do
      stub_const :PROCESS_TIME_SUPPORTED, false do
        result = @statsd.time('foobar') { 'test' }
        result.must_equal 'test'
      end
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        stub_time 0
        @statsd.time('foobar', :sample_rate=>0.5) do
          stub_time 1
        end
        socket.recv[0].must equal_with_telemetry 'foobar:1000|ms|@0.5'
      end
    end

    describe "with a sample rate like statsd-ruby" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        stub_time 0
        @statsd.time('foobar', 0.5) do
          stub_time 1
        end
        socket.recv[0].must equal_with_telemetry 'foobar:1000|ms|@0.5'
      end
    end
  end

  describe "#sampled" do
    describe "local setting" do
      describe "when the sample rate is 1" do
        before { class << @statsd; def rand; raise end; end }
        it "should send" do
          @statsd.timing('foobar', 500, :sample_rate=>1)
          socket.recv[0].must equal_with_telemetry 'foobar:500|ms'
        end
      end

      describe "when the sample rate is greater than a random value [0,1]" do
        before { class << @statsd; def rand; 0; end; end } # ensure delivery
        it "should send" do
          @statsd.timing('foobar', 500, :sample_rate=>0.5)
          socket.recv[0].must equal_with_telemetry 'foobar:500|ms|@0.5'
        end
      end

      describe "when the sample rate is less than a random value [0,1]" do
        before { class << @statsd; def rand; 1; end; end } # ensure no delivery
        it "should not send" do
          assert_nil @statsd.timing('foobar', 500, :sample_rate=>0.5)
        end
      end

      describe "when the sample rate is equal to a random value [0,1]" do
        before { class << @statsd; def rand; 0.5; end; end } # ensure delivery
        it "should send" do
          @statsd.timing('foobar', 500, :sample_rate=>0.5)
          socket.recv[0].must equal_with_telemetry 'foobar:500|ms|@0.5'
        end
      end
    end

    describe "global setting" do
      describe "when the sample rate is 1" do
        let(:sample_rate) { 1 }
        before { class << @statsd; def rand; raise end; end }
        it "should send" do
          @statsd.timing('foobar', 500)
          socket.recv[0].must equal_with_telemetry 'foobar:500|ms'
        end
      end

      describe "when the sample rate is greater than a random value [0,1]" do
        let(:sample_rate) { 0.5 }
        before { class << @statsd; def rand; 0; end; end } # ensure delivery
        it "should send" do
          @statsd.timing('foobar', 500)
          socket.recv[0].must equal_with_telemetry 'foobar:500|ms|@0.5'
        end
      end

      describe "when the sample rate is less than a random value [0,1]" do
        let(:sample_rate) { 0.5 }
        before { class << @statsd; def rand; 1; end; end } # ensure no delivery
        it "should not send" do
          assert_nil @statsd.timing('foobar', 500)
        end
      end

      describe "when the sample rate is equal to a random value [0,1]" do
        let(:sample_rate) { 0.5 }
        before { class << @statsd; def rand; 0.5; end; end } # ensure delivery
        it "should send" do
          @statsd.timing('foobar', 500)
          socket.recv[0].must equal_with_telemetry 'foobar:500|ms|@0.5'
        end
      end
    end
  end

  describe "#distribution" do
    it "send a message with d type" do
      @statsd.distribution('begrutten-suffusion', 536)
      socket.recv[0].must equal_with_telemetry 'begrutten-suffusion:536|d'
    end
  end

  describe "with namespace" do
    let(:namespace) { 'service' }

    it "should add namespace to increment" do
      @statsd.increment('foobar')
      socket.recv[0].must equal_with_telemetry 'service.foobar:1|c'
    end

    it "should add namespace to decrement" do
      @statsd.decrement('foobar')
      socket.recv[0].must equal_with_telemetry 'service.foobar:-1|c'
    end

    it "should add namespace to timing" do
      @statsd.timing('foobar', 500)
      socket.recv[0].must equal_with_telemetry 'service.foobar:500|ms'
    end

    it "should add namespace to gauge" do
      @statsd.gauge('foobar', 500)
      socket.recv[0].must equal_with_telemetry 'service.foobar:500|g'
    end
  end

  describe "with logging" do
    require 'stringio'
    let(:logger) { Logger.new(log) }
    let(:log) { StringIO.new }
    before { @statsd.connection.instance_variable_set(:@logger, logger) }

    it "writes to the log in debug" do
      logger.level = Logger::DEBUG

      @statsd.increment('foobar')

      log.string.must_match "Statsd: foobar:1|c"
    end

    it "does not write to the log unless debug" do
      logger.level = Logger::INFO

      @statsd.increment('foobar')

      log.string.must_be_empty
    end
  end

  describe "stat names" do
    it "should accept anything as stat" do
      @statsd.increment(Object)
    end

    it "should replace ruby constant delimeter with graphite package name" do
      class Datadog::Statsd::SomeClass; end
      @statsd.increment(Datadog::Statsd::SomeClass, :sample_rate=>1)

      socket.recv[0].must equal_with_telemetry 'Datadog.Statsd.SomeClass:1|c'
    end

    it "should replace statsd reserved chars in the stat name" do
      @statsd.increment('ray@hostname.blah|blah.blah:blah')
      socket.recv[0].must equal_with_telemetry 'ray_hostname.blah_blah.blah_blah:1|c'
    end

    it "should handle frozen strings" do
      @statsd.increment("some-stat".freeze)
    end
  end

  describe "tag names" do
    it "replaces reserved chars for tags" do
      @statsd.increment('stat', tags: ["name:foo,bar|foo"])
      socket.recv[0].must equal_with_telemetry 'stat:1|c|#name:foobarfoo'
    end

    it "handles the cases when some tags are frozen strings" do
      @statsd.increment('stat', tags: ["first_tag".freeze, "second_tag"])
    end

    it "converts all values to strings" do
      @statsd.increment('stat', tags: [:sample_tag])
      socket.recv[0].must equal_with_telemetry 'stat:1|c|#sample_tag'
    end
  end

  describe "handling socket errors" do
    before do
      @statsd.connection.instance_variable_set(:@logger, Logger.new(@log = StringIO.new))
      socket.instance_eval { def send(*) raise SocketError end }
    end

    it "should ignore socket errors" do
      assert_nil @statsd.increment('foobar')
    end

    it "should log socket errors" do
      @statsd.increment('foobar')
      @log.string.must_match 'Statsd: SocketError'
    end

    it "works without a logger" do
      @statsd.instance_variable_set(:@logger, nil)
      @statsd.increment('foobar')
    end
  end

  describe "handling closed socket" do
    before do
      @statsd.connection.instance_variable_set(:@logger, Logger.new(@log = StringIO.new))
    end

    it "tries to reconnect once" do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).returns("YEP") # 2nd call
      socket.expects(:send).raises(IOError.new("closed stream")) # first call

      @statsd.increment('foobar')
    end

    it "ignores and logs if it fails to reconnect" do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).raises(RuntimeError) # 2nd call
      socket.expects(:send).raises(IOError.new("closed stream")) # first call

      assert_nil @statsd.increment('foobar')
      @log.string.must_include 'Statsd: RuntimeError'
    end

    it "ignores and logs errors while trying to reconnect" do
      socket.expects(:send).raises(IOError.new("closed stream"))
      @statsd.connection.expects(:connect).raises(SocketError)

      assert_nil @statsd.increment('foobar')
      @log.string.must_include 'Statsd: SocketError'
    end
  end

  describe "handling not connected socket" do
    before do
      @statsd.connection.instance_variable_set(:@logger, Logger.new(@log = StringIO.new))
    end

    it "tries to reconnect once" do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).returns("YEP") # 2nd call
      socket.expects(:send).raises(Errno::ENOTCONN.new("closed stream")) # first call

      @statsd.increment('foobar')
    end

    it "ignores and logs if it fails to reconnect" do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).raises(RuntimeError) # 2nd call
      socket.expects(:send).raises(Errno::ENOTCONN.new) # first call

      assert_nil @statsd.increment('foobar')
      @log.string.must_include 'Statsd: RuntimeError'
    end

    it "ignores and logs errors while trying to reconnect" do
      socket.expects(:send).raises(Errno::ENOTCONN.new)
      @statsd.connection.expects(:connect).raises(SocketError)

      assert_nil @statsd.increment('foobar')
      @log.string.must_include 'Statsd: SocketError'
    end
  end

  describe "handling connection refused" do
    before do
      @statsd.connection.instance_variable_set(:@logger, Logger.new(@log = StringIO.new))
    end

    it "tries to reconnect once" do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).returns("YEP") # 2nd call
      socket.expects(:send).raises(Errno::ECONNREFUSED.new("closed stream")) # first call

      @statsd.increment('foobar')
    end

    it "ignores and logs if it fails to reconnect" do
      @statsd.connection.expects(:socket).times(2).returns(socket)
      socket.expects(:send).raises(RuntimeError) # 2nd call
      socket.expects(:send).raises(Errno::ECONNREFUSED.new) # first call

      assert_nil @statsd.increment('foobar')
      @log.string.must_include 'Statsd: RuntimeError'
    end

    it "ignores and logs errors while trying to reconnect" do
      socket.expects(:send).raises(Errno::ECONNREFUSED.new)
      @statsd.connection.expects(:connect).raises(SocketError)

      assert_nil @statsd.increment('foobar')
      @log.string.must_include 'Statsd: SocketError'
    end
  end

  describe "UDS error handling" do
    before do
      @statsd = Datadog::Statsd.new('localhost', 1234, socket_path: '/tmp/socket', disable_telemetry: true)
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
    describe "tags as an array of strings" do
      it "gauges support tags" do
        @statsd.gauge("gauge", 1, :tags=>%w(country:usa state:ny))
        socket.recv[0].must equal_with_telemetry 'gauge:1|g|#country:usa,state:ny'
      end

      it "counters support tags" do
        @statsd.increment("c", :tags=>%w(country:usa other))
        socket.recv[0].must equal_with_telemetry 'c:1|c|#country:usa,other'

        @statsd.telemetry.reset
        @statsd.decrement("c", :tags=>%w(country:china))
        socket.recv[0].must equal_with_telemetry 'c:-1|c|#country:china'

        @statsd.telemetry.reset
        @statsd.count("c", 100, :tags=>%w(country:finland))
        socket.recv[0].must equal_with_telemetry 'c:100|c|#country:finland'
      end

      it "timing support tags" do
        @statsd.timing("t", 200, :tags=>%w(country:canada other))
        socket.recv[0].must equal_with_telemetry 't:200|ms|#country:canada,other'

        @statsd.time('foobar', :tags => ["123"]) { sleep(0.001); 'test' }
      end

      it "global tags setter" do
        @statsd.instance_variable_set(:@tags, %w(country:usa other))
        @statsd.increment("c")
        socket.recv[0].must equal_with_telemetry 'c:1|c|#country:usa,other'
      end

      it "global tags setter and regular tags" do
        @statsd.instance_variable_set(:@tags, %w(country:usa other))
        @statsd.increment("c", :tags=>%w(somethingelse))
        socket.recv[0].must equal_with_telemetry 'c:1|c|#country:usa,other,somethingelse'
      end
    end

    describe "tags as hashes" do
      it "gauges support tags" do
        @statsd.gauge("gauge", 1, :tags =>{ country: 'usa', state: 'ny' })
        socket.recv[0].must equal_with_telemetry 'gauge:1|g|#country:usa,state:ny'
      end

      it "counters support tags" do
        @statsd.increment("c", :tags => { country: 'usa', other: nil })
        socket.recv[0].must equal_with_telemetry 'c:1|c|#country:usa,other'

        @statsd.telemetry.reset
        @statsd.decrement("c", :tags => { country: 'china' })
        socket.recv[0].must equal_with_telemetry 'c:-1|c|#country:china'

        @statsd.telemetry.reset
        @statsd.count("c", 100, :tags => { country: 'finland' })
        socket.recv[0].must equal_with_telemetry 'c:100|c|#country:finland'
      end

      it "timing support tags" do
        @statsd.timing("t", 200, :tags => { country: 'canada', other: nil })
        socket.recv[0].must equal_with_telemetry 't:200|ms|#country:canada,other'

        @statsd.time('foobar', :tags => ["123"]) { sleep(0.001); 'test' }
      end

      it "global tags setter and regular tags" do
        @statsd.instance_variable_set(:@tags, %w(country:usa other))
        @statsd.increment("c", :tags=> { something: 'else'})
        socket.recv[0].must equal_with_telemetry 'c:1|c|#country:usa,other,something:else'
      end

    end
  end

  describe "batched" do
    it "should not send anything when the buffer is empty" do
      @statsd.batch { }
      assert_nil socket.recv
    end

    it "should allow to send single sample in one packet" do
      @statsd.batch do |s|
        s.increment("mycounter")
      end
      socket.recv[0].must equal_with_telemetry 'mycounter:1|c'
    end

    it "should allow to send multiple sample in one packet" do
      @statsd.batch do |s|
        s.increment("mycounter")
        s.decrement("myothercounter")
      end
      socket.recv[0].must equal_with_telemetry("mycounter:1|c\nmyothercounter:-1|c", metrics: 2)
    end

    it "should default back to single metric packet after the block" do
      @statsd.batch do |s|
        s.gauge("mygauge", 10)
        s.gauge("myothergauge", 20)
      end
      @statsd.increment("mycounter")
      @statsd.increment("myothercounter")

      equal_expected = equal_with_telemetry("mygauge:10|g\nmyothergauge:20|g", metrics: 2)
      socket.recv[0].must equal_expected

      equal_expected = equal_with_telemetry('mycounter:1|c', bytes_sent: equal_expected.length, packets_sent: 1)
      socket.recv[0].must equal_expected

      equal_expected = equal_with_telemetry('myothercounter:1|c', bytes_sent: equal_expected.length, packets_sent: 1)
      socket.recv[0].must equal_expected
    end

    it "should flush when the buffer gets too big" do
      expected_message = 'mycounter:1|c'
      previous_payload_length = 0

      @statsd.batch do |s|
        # increment a counter to fill the buffer and trigger buffer flush
        buffer_size = Datadog::Statsd::DEFAULT_BUFFER_SIZE - @statsd.telemetry.estimate_max_size() - 1

        number_of_messages_to_fill_the_buffer = buffer_size / (expected_message.bytesize + 1)
        theoretical_reply = Array.new(number_of_messages_to_fill_the_buffer) { expected_message }

        (number_of_messages_to_fill_the_buffer + 1).times do
          s.increment("mycounter")
        end

        equal_expected = equal_with_telemetry(theoretical_reply.join("\n"), metrics: number_of_messages_to_fill_the_buffer+1)
        socket.recv[0].must equal_expected
        previous_payload_length = equal_expected.length
      end

      # When the block finishes, the remaining buffer is flushed.
      #
      # We increment the telemetry metrics count when we receive it, not when
      # flush. This means that the last metric (who filled the buffer and triggered a
      # flush) increment the telemetry but was not sent. Then once the 'do' block
      # finishes we flush the buffer with a telemtry of 0 metrics being received.
      socket.recv[0].must equal_with_telemetry(expected_message, metrics: 0, bytes_sent: previous_payload_length, packets_sent: 1)
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
      equal_expected = equal_with_telemetry("level-1:1|c\nlevel-2:1|c\nlevel-1-again:1|c", metrics: 3)
      socket.recv[0].must equal_expected
      # we should revert back to sending single metric packets
      @statsd.increment("outside")
      socket.recv[0].must equal_with_telemetry("outside:1|c", bytes_sent: equal_expected.length, packets_sent: 1)
    end
  end

  describe "#event" do
    10.times do
      title = Faker::Lorem.sentence(_word_count =  rand(3))
      text = Faker::Lorem.sentence(_word_count = rand(3))
      tags = Faker::Lorem.words(rand(1..10))
      timestamp = Time.parse('01-01-2000').to_i
      tags_joined = tags.join(",")

      it "Only title and text" do
        @statsd.event(title, text)
        socket.recv[0].must equal_with_telemetry(@statsd.send(:format_event, title, text), metrics: 0, events: 1)
      end
      it "With line break in Text and title" do
        title_break_line = "#{title} \n second line"
        text_break_line = "#{text} \n second line"
        @statsd.event(title_break_line, text_break_line)
        socket.recv[0].must equal_with_telemetry(@statsd.send(:format_event, title_break_line, text_break_line), metrics: 0, events: 1)
      end
      it "Event data string too long > 8KB" do
        long_text = "#{text} " * 200000
        proc {@statsd.event(title, long_text)}.must_raise RuntimeError
      end
      it "With known alert_type" do
        @statsd.event(title, text, :alert_type => 'warning')
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|t:warning", metrics: 0, events: 1)
      end
      it "With unknown alert_type" do
        @statsd.event(title, text, :alert_type => 'bizarre')
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|t:bizarre", metrics: 0, events: 1)
      end
      it "With known priority" do
        @statsd.event(title, text, :priority => 'low')
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|p:low", metrics: 0, events: 1)
      end
      it "With unknown priority" do
        @statsd.event(title, text, :priority => 'bizarre')
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|p:bizarre", metrics: 0, events: 1)
      end
      it "With Integer date_happened" do
        @statsd.event(title, text, :date_happened => timestamp)
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|d:#{timestamp}", metrics: 0, events: 1)
      end
      it "With String date_happened" do
        @statsd.event(title, text, :date_happened => "#{timestamp}")
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|d:#{timestamp}", metrics: 0, events: 1)
      end
      it "With hostname" do
        @statsd.event(title, text, :hostname => 'hostname_test')
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|h:hostname_test", metrics: 0, events: 1)
      end
      it "With aggregation_key" do
        @statsd.event(title, text, :aggregation_key => 'aggkey 1')
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|k:aggkey 1", metrics: 0, events: 1)
      end
      it "With source_type_name" do
        @statsd.event(title, text, :source_type_name => 'source 1')
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|s:source 1", metrics: 0, events: 1)
      end
      it "With several tags" do
        @statsd.event(title, text, :tags => tags)
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text)}|##{tags_joined}", metrics: 0, events: 1)
      end
      it "Takes into account the common tags" do
        basic_result = @statsd.send(:format_event, title, text)
        common_tag = 'common'
        @statsd.instance_variable_set :@tags, [common_tag]
        @statsd.event(title, text)
        socket.recv[0].must equal_with_telemetry("#{basic_result}|##{common_tag}", metrics: 0, events: 1)
      end
      it "combines common and specific tags" do
        basic_result = @statsd.send(:format_event, title, text)
        common_tag = 'common'
        @statsd.instance_variable_set :@tags, [common_tag]
        @statsd.event(title, text, :tags => tags)
        socket.recv[0].must equal_with_telemetry("#{basic_result}|##{common_tag},#{tags_joined}", metrics: 0, events: 1)
      end
      it "With alert_type, priority, hostname, several tags" do
        @statsd.event(title, text, :alert_type => 'warning', :priority => 'low', :hostname => 'hostname_test', :tags => tags)
        opts = {
          :alert_type => 'warning',
          :priority => 'low',
          :hostname => 'hostname_test',
          :tags => tags
        }
        socket.recv[0].must equal_with_telemetry("#{@statsd.send(:format_event, title, text, opts)}", metrics: 0, events: 1)
      end
    end
  end

  describe "#service_check" do
    10.times do
      name = Faker::Lorem.sentence(_word_count = rand(3))
      status = rand(4)
      hostname = "hostname_test"
      timestamp = Time.parse('01-01-2000').to_i
      tags = Faker::Lorem.words(rand(1..10))
      tags_joined = tags.join(",")

      it "sends with only name and status" do
        @statsd.service_check(name, status)
        socket.recv[0].must equal_with_telemetry(@statsd.send(:format_service_check, name, status), metrics: 0, service_checks: 1)
      end

      it "sends with with hostname" do
        @statsd.service_check(name, status, :hostname => hostname)
        socket.recv[0].must equal_with_telemetry("_sc|#{name}|#{status}|h:#{hostname}", metrics: 0, service_checks: 1)
      end

      it "sends with with message" do
        @statsd.service_check(name, status, :message => 'testing | m: \n')
        socket.recv[0].must equal_with_telemetry("_sc|#{name}|#{status}|m:testing  m\\: \\n", metrics: 0, service_checks: 1)
      end

      it "With Integer timestamp" do
        @statsd.service_check(name, status, :timestamp => timestamp)
        socket.recv[0].must equal_with_telemetry("_sc|#{name}|#{status}|d:#{timestamp}", metrics: 0, service_checks: 1)
      end

      it "With String timestamp" do
        @statsd.service_check(name, status, :timestamp => "#{timestamp}")
        socket.recv[0].must equal_with_telemetry("_sc|#{name}|#{status}|d:#{timestamp}", metrics: 0, service_checks: 1)
      end

      it "sends with with tags" do
        @statsd.service_check(name, status, :tags => tags)
        socket.recv[0].must equal_with_telemetry("_sc|#{name}|#{status}|##{tags_joined}", metrics: 0, service_checks: 1)
      end

      it "sends with with hostname, message, and tags" do
        @statsd.service_check(
          name, status,
          :message => 'testing | m: \n', :hostname => 'hostname_test', :tags => tags
        )
        socket.recv[0].must equal_with_telemetry("_sc|#{name}|#{status}|h:#{hostname}|##{tags_joined}|m:testing  m\\: \\n", metrics: 0, service_checks: 1)
      end
    end
  end

  describe "telemetry" do
    it "should not be sent when disabled" do
      statsd = Datadog::Statsd.new('localhost', 1234, disable_telemetry: true)
      statsd.connection.instance_variable_set(:@socket, socket)

      statsd.count("test", 21)
      socket.recv[0].must_equal "test:21|c"
    end

    it "should send by default" do
      statsd = Datadog::Statsd.new('localhost', 1234)
      statsd.connection.instance_variable_set(:@socket, socket)

      statsd.count("test", 21)
      socket.recv[0].must equal_with_telemetry "test:21|c"
    end

    it "should handle all data type" do
      @statsd.increment("test", 1)
      socket.recv[0].must equal_with_telemetry("test:1|c", metrics: 1, packets_sent: 0, bytes_sent: 0)

      @statsd.decrement("test", 1)
      socket.recv[0].must equal_with_telemetry("test:-1|c", metrics: 1, packets_sent: 1, bytes_sent: 680)

      @statsd.count("test", 21)
      socket.recv[0].must equal_with_telemetry("test:21|c", metrics: 1, packets_sent: 1, bytes_sent: 683)

      @statsd.gauge("test", 21)
      socket.recv[0].must equal_with_telemetry("test:21|g", metrics: 1, packets_sent: 1, bytes_sent: 683)

      @statsd.histogram("test", 21)
      socket.recv[0].must equal_with_telemetry("test:21|h", metrics: 1, packets_sent: 1, bytes_sent: 683)

      @statsd.timing("test", 21)
      socket.recv[0].must equal_with_telemetry("test:21|ms", metrics: 1, packets_sent: 1, bytes_sent: 683)

      @statsd.set("test", 21)
      socket.recv[0].must equal_with_telemetry("test:21|s", metrics: 1, packets_sent: 1, bytes_sent: 684)

      @statsd.service_check("sc", 0)
      socket.recv[0].must equal_with_telemetry("_sc|sc|0", metrics: 0, service_checks: 1, packets_sent: 1, bytes_sent: 683)

      @statsd.event("ev", "text")
      socket.recv[0].must equal_with_telemetry("_e{2,4}:ev|text", metrics: 0, events: 1, packets_sent: 1, bytes_sent: 682)
    end

    it "should handle all data type when batched" do
      @statsd.batch do |s|
        s.increment("test", 1)
        s.decrement("test", 1)
        s.count("test", 21)
        s.gauge("test", 21)
        s.histogram("test", 21)
        s.timing("test", 21)
        s.set("test", 21)
        s.service_check("sc", 0)
        s.event("ev", "text")
      end

      socket.recv[0].must equal_with_telemetry("test:1|c\ntest:-1|c\ntest:21|c\ntest:21|g\ntest:21|h\ntest:21|ms\ntest:21|s\n_sc|sc|0\n_e{2,4}:ev|text", metrics: 7, service_checks: 1, events: 1)
      @statsd.telemetry.flush().must equal_with_telemetry("", metrics: 0, service_checks: 0, events: 0, packets_sent: 1, bytes_sent: 766)
    end

    it "should handle dropped data" do
      s = FakeUDPSocket.new
      s.error_on_send "some error"

      statsd = Datadog::Statsd.new('localhost', 1234)
      statsd.connection.instance_variable_set(:@socket, s)

      statsd.gauge("test", 21)
      statsd.telemetry.flush().must equal_with_telemetry("", metrics: 1, service_checks: 0, events: 0, packets_dropped: 1, bytes_dropped: 681)
      statsd.gauge("test", 21)
      statsd.telemetry.flush().must equal_with_telemetry("", metrics: 2, service_checks: 0, events: 0, packets_dropped: 2, bytes_dropped: 1364)

      #disable network failure
      s.error_on_send nil

      statsd.gauge("test", 21)
      s.recv[0].must equal_with_telemetry("test:21|g", metrics: 3, service_checks: 0, events: 0, packets_dropped: 2, bytes_dropped: 1364)

      statsd.telemetry.flush().must equal_with_telemetry("", metrics: 0, service_checks: 0, events: 0, packets_sent: 1, bytes_sent: 684)
    end
  end

  describe "#close" do
    it "closes the socket" do
      socket.expects(:close)
      @statsd.close
    end
  end

  describe "GC" do
    before { skip('AllocationStats is not available: skipping.') unless defined?(AllocationStats) }

    it "produces low amounts of garbage for simple methods" do
      assert_allocations(15) { @statsd.increment('foobar') }
    end

    it "produces low amounts of garbage for timing" do
      assert_allocations(15) { @statsd.time('foobar') { 1111 } }
    end

    it "produces low amounts of garbage for simple methods without telemetry" do
      statsd = Datadog::Statsd.new('localhost', 1234, namespace: namespace, sample_rate: sample_rate, disable_telemetry: true)
      statsd.connection.instance_variable_set(:@socket, socket)
      assert_allocations(7) { statsd.increment('foobar') }
      assert_allocations(7) { statsd.time('foobar') { 1111 } }
    end

    def assert_allocations(count, &block)
      trace = AllocationStats.trace(&block)
      details = trace.allocations
        .group_by(:sourcefile, :sourceline, :class)
        .sort_by_count
        .to_text
      trace.new_allocations.size.must_equal count, details
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

  def stub_const(const, value)
    old = Datadog::Statsd.const_get(const)
    Datadog::Statsd.send(:remove_const, const)
    Datadog::Statsd.const_set(const, value)
    yield
  ensure
    Datadog::Statsd.send(:remove_const, const)
    Datadog::Statsd.const_set(const, old)
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
