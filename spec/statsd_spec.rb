require 'helper'
require 'timecop'

describe Statsd do
  class Statsd
    # we need to stub this
    attr_accessor :socket
  end

  before do
    @statsd = Statsd.new('localhost', 1234)
    @statsd.socket = FakeUDPSocket.new
  end

  after { @statsd.socket.clear }

  describe "#initialize" do
    it "should set the host and port" do
      @statsd.host.must_equal 'localhost'
      @statsd.port.must_equal 1234
    end

    it "should default the host to 127.0.0.1, port to 8125, namespace to nil, and tags to []" do
      statsd = Statsd.new
      statsd.host.must_equal '127.0.0.1'
      statsd.port.must_equal 8125
      statsd.namespace.must_equal nil
      statsd.tags.must_equal []
    end

    it 'should be able to set host, port, namespace, and global tags' do
      statsd = Statsd.new '1.3.3.7', 8126, :tags => %w(global), :namespace => 'space'
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
      @statsd.tags = 't4g5'

      @statsd.host.must_equal '1.2.3.4'
      @statsd.port.must_equal 5678
      @statsd.namespace.must_equal 'n4m35p4c3'
      @statsd.tags.must_equal 't4g5'
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
      @statsd.namespace.must_equal nil
      @statsd.instance_variable_get('@prefix').must_equal nil
    end

    it 'should set nil tags to default' do
      @statsd.tags = nil
      @statsd.tags.must_equal []
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
  end

  describe "#gauge" do
    it "should send a message with a 'g' type, per the nearbuy fork" do
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
  end

  describe "#histogram" do
    it "should send a message with a 'h' type, per the nearbuy fork" do
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
    it "should send a message with a 's' type, per the nearbuy fork" do
      @statsd.set('my.set', 536)
      @statsd.socket.recv.must_equal ['my.set:536|s']
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
  end

  describe "#time" do
    describe "With actual time testing" do
      before do
        # Freezing time to prevent random test failures
        Timecop.freeze Time.now
      end

      after do
        Timecop.return
      end

      it "should format the message according to the statsd spec" do
        @statsd.time('foobar') do
          Timecop.freeze(Time.now + 1)
        end
        @statsd.socket.recv.must_equal ['foobar:1000|ms']
      end

      it "should still time if block is failing" do
        @statsd.time('foobar') do
          Timecop.freeze(Time.now + 1)
          raise StandardError, 'This is failing'
        end rescue
        @statsd.socket.recv.must_equal ['foobar:1000|ms']
      end
    end

    it "should return the result of the block" do
      result = @statsd.time('foobar') { 'test' }
      result.must_equal 'test'
    end

    it "should reraise the error if block is failing" do
      expect do
        @statsd.time('foobar') { raise StandardError, 'This is failing' }
      end.must_raise StandardError
    end

    describe "with a sample rate" do
      before { class << @statsd; def rand; 0; end; end } # ensure delivery

      it "should format the message according to the statsd spec" do
        result = @statsd.time('foobar', :sample_rate=>0.5) { sleep(0.001); 'test' }
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
        @statsd.timing('foobar', 500, :sample_rate=>0.5).must_equal nil
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
    before { Statsd.logger = Logger.new(@log = StringIO.new)}

    it "should write to the log in debug" do
      Statsd.logger.level = Logger::DEBUG

      @statsd.increment('foobar')

      @log.string.must_match "Statsd: foobar:1|c"
    end

    it "should not write to the log unless debug" do
      Statsd.logger.level = Logger::INFO

      @statsd.increment('foobar')

      @log.string.must_be_empty
    end
  end

  describe "stat names" do
    it "should accept anything as stat" do
      @statsd.increment(Object)
    end

    it "should replace ruby constant delimeter with graphite package name" do
      class Statsd::SomeClass; end
      @statsd.increment(Statsd::SomeClass, :sample_rate=>1)

      @statsd.socket.recv.must_equal ['Statsd.SomeClass:1|c']
    end

    it "should replace statsd reserved chars in the stat name" do
      @statsd.increment('ray@hostname.blah|blah.blah:blah')
      @statsd.socket.recv.must_equal ['ray_hostname.blah_blah.blah_blah:1|c']
    end
  end

  describe "tag names" do
    it "replaces reserved chars for tags" do
      @statsd.increment('stat', tags: ["name:foo,bar|foo"])
      @statsd.socket.recv.must_equal ['stat:1|c|#name:foobarfoo']
    end
  end

  describe "handling socket errors" do
    before do
      require 'stringio'
      Statsd.logger = Logger.new(@log = StringIO.new)
      @statsd.socket.instance_eval { def send(*) raise SocketError end }
    end

    it "should ignore socket errors" do
      @statsd.increment('foobar').must_equal nil
    end

    it "should log socket errors" do
      @statsd.increment('foobar')
      @log.string.must_match 'Statsd: SocketError'
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
  end

  describe "#event" do
    nb_tests = 10
    for i in 00..nb_tests
      title = Faker::Lorem.sentence(word_count =  rand(3))
      text = Faker::Lorem.sentence(word_count = rand(3))
      title_len = title.length
      text_len = text.length
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
    nb_tests = 10
    for i in 00..nb_tests
      name = Faker::Lorem.sentence(word_count =  rand(3))
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
end

describe Statsd do
  describe "with a real UDP socket" do
    it "should actually send stuff over the socket" do
      socket = UDPSocket.new
      host, port = 'localhost', 12345
      socket.bind(host, port)

      statsd = Statsd.new(host, port)
      statsd.increment('foobar')
      message = socket.recvfrom(16).first
      message.must_equal 'foobar:1|c'
    end
  end
end if ENV['LIVE']
