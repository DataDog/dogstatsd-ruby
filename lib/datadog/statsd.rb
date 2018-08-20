# frozen_string_literal: true
require 'socket'

# = Datadog::Statsd: A DogStatsd client (https://www.datadoghq.com)
#
# @example Set up a global Statsd client for a server on localhost:8125
#   require 'datadog/statsd'
#   $statsd = Datadog::Statsd.new 'localhost', 8125
# @example Send some stats
#   $statsd.increment 'page.views'
#   $statsd.timing 'page.load', 320
#   $statsd.gauge 'users.online', 100
# @example Use {#time} to time the execution of a block
#   $statsd.time('account.activate') { @account.activate! }
# @example Create a namespaced statsd client and increment 'account.activate'
#   statsd = Datadog::Statsd.new 'localhost', 8125, :namespace => 'account'
#   statsd.increment 'activate'
# @example Create a statsd client with global tags
#   statsd = Datadog::Statsd.new 'localhost', 8125, tags: 'tag1:true'
module Datadog
  class Statsd

    class Connection
      DEFAULT_HOST = '127.0.0.1'
      DEFAULT_PORT = 8125

      # StatsD host. Defaults to 127.0.0.1.
      attr_reader :host

      # StatsD port. Defaults to 8125.
      attr_reader :port

      # DogStatsd unix socket path. Not used by default.
      attr_reader :socket_path

      def initialize(host, port, socket_path, logger)
        @host = host || DEFAULT_HOST
        @port = port || DEFAULT_PORT
        @socket_path = socket_path
        @logger = logger
      end

      def write(message)
        @logger.debug { "Statsd: #{message}" } if @logger
        if @socket_path.nil?
          socket.send(message, 0)
        else
          socket.sendmsg_nonblock(message)
        end
      rescue StandardError => boom
        # Give up on this socket if it looks like it is bad
        bad_socket = !@socket_path.nil? && (
          boom.is_a?(Errno::ECONNREFUSED) ||
          boom.is_a?(Errno::ECONNRESET) ||
          boom.is_a?(Errno::ENOENT)
        )
        if bad_socket
          @socket = nil
          return
        end

        # Try once to reconnect if the socket has been closed
        retries ||= 1
        if retries <= 1 && boom.is_a?(IOError) && boom.message =~ /closed stream/i
          retries += 1
          begin
            @socket = connect
            retry
          rescue StandardError => e
            boom = e
          end
        end

        @logger.error { "Statsd: #{boom.class} #{boom}" } if @logger
        nil
      end

      # Close the underlying socket
      def close
        @socket && @socket.close
      end

      private

      def socket
        @socket ||= connect
      end

      def connect
        if @socket_path.nil?
          socket = UDPSocket.new
          socket.connect(@host, @port)
        else
          socket = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM)
          socket.connect(Socket.pack_sockaddr_un(@socket_path))
        end
        socket
      end
    end

    class Batch
      def initialize(connection, max_buffer_bytes)
        @connection = connection
        @max_buffer_bytes = max_buffer_bytes
        @depth = 0
        reset
      end

      def open
        @depth += 1
        yield
      ensure
        @depth -= 1
        flush if !open?
      end

      def open?
        @depth > 0
      end

      def add(message)
        message_bytes = message.bytesize

        unless @buffer_bytes == 0
          if @buffer_bytes + 1 + message_bytes >= @max_buffer_bytes
            flush
          else
            @buffer << NEW_LINE
            @buffer_bytes += 1
          end
        end

        @buffer << message
        @buffer_bytes += message_bytes
      end

      def flush
        return if @buffer_bytes == 0
        @connection.write @buffer
        reset
      end

      private

      def reset
        @buffer = String.new
        @buffer_bytes = 0
      end
    end

    # Create a dictionary to assign a key to every parameter's name, except for tags (treated differently)
    # Goal: Simple and fast to add some other parameters
    OPTS_KEYS = {
      :date_happened     => :d,
      :hostname          => :h,
      :aggregation_key   => :k,
      :priority          => :p,
      :source_type_name  => :s,
      :alert_type        => :t,
    }

    # Service check options
    SC_OPT_KEYS = {
      :timestamp  => 'd:'.freeze,
      :hostname   => 'h:'.freeze,
      :tags       => '#'.freeze,
      :message    => 'm:'.freeze,
    }

    OK        = 0
    WARNING   = 1
    CRITICAL  = 2
    UNKNOWN   = 3

    MAX_EVENT_SIZE = 8 * 1024

    COUNTER_TYPE = 'c'.freeze
    GAUGE_TYPE = 'g'.freeze
    HISTOGRAM_TYPE = 'h'.freeze
    DISTRIBUTION_TYPE = 'd'.freeze
    TIMING_TYPE = 'ms'.freeze
    SET_TYPE = 's'.freeze
    VERSION = "4.0.0".freeze

    # A namespace to prepend to all statsd calls. Defaults to no namespace.
    attr_reader :namespace

    # Global tags to be added to every statsd call. Defaults to no tags.
    attr_reader :tags

    # Buffer containing the statsd message before they are sent in batch
    attr_reader :buffer

    # Maximum buffer size in bytes before it is flushed
    attr_reader :max_buffer_bytes

    # Connection
    attr_reader :connection

    # @param [String] host your statsd host
    # @param [Integer] port your statsd port
    # @option [String] namespace set a namespace to be prepended to every metric name
    # @option [Array<String>] tags tags to be added to every metric
    # @option [Loger] logger for debugging
    # @option [Integer] max_buffer_bytes max bytes to buffer when using #batch
    # @option [String] socket_path unix socket path
    def initialize(
      host = nil,
      port = nil,
      namespace: nil,
      tags: nil,
      max_buffer_bytes: 8192,
      socket_path: nil,
      logger: nil
    )
      @connection = Connection.new(host, port, socket_path, logger)
      @logger = logger

      @namespace = namespace
      @prefix = @namespace ? "#{@namespace}.".freeze : nil

      raise ArgumentError, 'tags must be a Array<String>' unless tags.nil? or tags.is_a? Array
      @tags = (tags || []).compact.map! {|tag| escape_tag_content(tag)}

      @batch = Batch.new @connection, max_buffer_bytes
    end

    # yield a new instance to a block and close it when done
    # for short-term use-cases that don't want to close the socket manually
    def self.open(*args)
      instance = new(*args)
      yield instance
    ensure
      instance.close
    end

    # Sends an increment (count = 1) for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @option opts [Numeric] :by increment value, default 1
    # @see #count
    def increment(stat, opts=EMPTY_OPTIONS)
      opts = {:sample_rate => opts} if opts.is_a? Numeric
      incr_value = opts.fetch(:by, 1)
      count stat, incr_value, opts
    end

    # Sends a decrement (count = -1) for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @option opts [Numeric] :by decrement value, default 1
    # @see #count
    def decrement(stat, opts=EMPTY_OPTIONS)
      opts = {:sample_rate => opts} if opts.is_a? Numeric
      decr_value = - opts.fetch(:by, 1)
      count stat, decr_value, opts
    end

    # Sends an arbitrary count for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Integer] count count
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    def count(stat, count, opts=EMPTY_OPTIONS)
      opts = {:sample_rate => opts} if opts.is_a? Numeric
      send_stats stat, count, COUNTER_TYPE, opts
    end

    # Sends an arbitary gauge value for the given stat to the statsd server.
    #
    # This is useful for recording things like available disk space,
    # memory usage, and the like, which have different semantics than
    # counters.
    #
    # @param [String] stat stat name.
    # @param [Numeric] value gauge value.
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @example Report the current user count:
    #   $statsd.gauge('user.count', User.count)
    def gauge(stat, value, opts=EMPTY_OPTIONS)
      opts = {:sample_rate => opts} if opts.is_a? Numeric
      send_stats stat, value, GAUGE_TYPE, opts
    end

    # Sends a value to be tracked as a histogram to the statsd server.
    #
    # @param [String] stat stat name.
    # @param [Numeric] value histogram value.
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @example Report the current user count:
    #   $statsd.histogram('user.count', User.count)
    def histogram(stat, value, opts=EMPTY_OPTIONS)
      send_stats stat, value, HISTOGRAM_TYPE, opts
    end

    # Sends a value to be tracked as a distribution to the statsd server.
    # Note: Distributions are a beta feature of Datadog and not generally
    # available. Distributions must be specifically enabled for your
    # organization.
    #
    # @param [String] stat stat name.
    # @param [Numeric] value distribution value.
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @example Report the current user count:
    #   $statsd.distribution('user.count', User.count)
    def distribution(stat, value, opts=EMPTY_OPTIONS)
      send_stats stat, value, DISTRIBUTION_TYPE, opts
    end

    # Sends a timing (in ms) for the given stat to the statsd server. The
    # sample_rate determines what percentage of the time this report is sent. The
    # statsd server then uses the sample_rate to correctly track the average
    # timing for the stat.
    #
    # @param [String] stat stat name
    # @param [Integer] ms timing in milliseconds
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    def timing(stat, ms, opts=EMPTY_OPTIONS)
      opts = {:sample_rate => opts} if opts.is_a? Numeric
      send_stats stat, ms, TIMING_TYPE, opts
    end

    # Reports execution time of the provided block using {#timing}.
    #
    # If the block fails, the stat is still reported, then the error
    # is reraised
    #
    # @param [String] stat stat name
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @yield The operation to be timed
    # @see #timing
    # @example Report the time (in ms) taken to activate an account
    #   $statsd.time('account.activate') { @account.activate! }
    def time(stat, opts=EMPTY_OPTIONS)
      opts = {:sample_rate => opts} if opts.is_a? Numeric
      start = (PROCESS_TIME_SUPPORTED ? Process.clock_gettime(Process::CLOCK_MONOTONIC) : Time.now.to_f)
      return yield
    ensure
      finished = (PROCESS_TIME_SUPPORTED ? Process.clock_gettime(Process::CLOCK_MONOTONIC) : Time.now.to_f)
      timing(stat, ((finished - start) * 1000).round, opts)
    end

    # Sends a value to be tracked as a set to the statsd server.
    #
    # @param [String] stat stat name.
    # @param [Numeric] value set value.
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @example Record a unique visitory by id:
    #   $statsd.set('visitors.uniques', User.id)
    def set(stat, value, opts=EMPTY_OPTIONS)
      opts = {:sample_rate => opts} if opts.is_a? Numeric
      send_stats stat, value, SET_TYPE, opts
    end

    # This method allows you to send custom service check statuses.
    #
    # @param [String] name Service check name
    # @param [String] status Service check status.
    # @param [Hash] opts the additional data about the service check
      # @option opts [Integer, nil] :timestamp (nil) Assign a timestamp to the event. Default is now when none
      # @option opts [String, nil] :hostname (nil) Assign a hostname to the event.
      # @option opts [Array<String>, nil] :tags (nil) An array of tags
      # @option opts [String, nil] :message (nil) A message to associate with this service check status
    # @example Report a critical service check status
    #   $statsd.service_check('my.service.check', Statsd::CRITICAL, :tags=>['urgent'])
    def service_check(name, status, opts=EMPTY_OPTIONS)
      send_stat format_service_check(name, status, opts)
    end

    # This end point allows you to post events to the stream. You can tag them, set priority and even aggregate them with other events.
    #
    # Aggregation in the stream is made on hostname/event_type/source_type/aggregation_key.
    # If there's no event type, for example, then that won't matter;
    # it will be grouped with other events that don't have an event type.
    #
    # @param [String] title Event title
    # @param [String] text Event text. Supports \n
    # @param [Hash] opts the additional data about the event
    # @option opts [Integer, nil] :date_happened (nil) Assign a timestamp to the event. Default is now when none
    # @option opts [String, nil] :hostname (nil) Assign a hostname to the event.
    # @option opts [String, nil] :aggregation_key (nil) Assign an aggregation key to the event, to group it with some others
    # @option opts [String, nil] :priority ('normal') Can be "normal" or "low"
    # @option opts [String, nil] :source_type_name (nil) Assign a source type to the event
    # @option opts [String, nil] :alert_type ('info') Can be "error", "warning", "info" or "success".
    # @option opts [Array<String>] :tags tags to be added to every metric
    # @example Report an awful event:
    #   $statsd.event('Something terrible happened', 'The end is near if we do nothing', :alert_type=>'warning', :tags=>['end_of_times','urgent'])
    def event(title, text, opts=EMPTY_OPTIONS)
      send_stat format_event(title, text, opts)
    end

    # Send several metrics in the same UDP Packet
    # They will be buffered and flushed when the block finishes
    #
    # @example Send several metrics in one packet:
    #   $statsd.batch do |s|
    #      s.gauge('users.online',156)
    #      s.increment('page.views')
    #    end
    def batch
      @batch.open { yield self }
    end

    # Close the underlying socket
    def close
      @connection.close
    end

    private

    NEW_LINE = "\n".freeze
    ESC_NEW_LINE = "\\n".freeze
    COMMA = ",".freeze
    PIPE = "|".freeze
    DOT = ".".freeze
    DOUBLE_COLON = "::".freeze
    UNDERSCORE = "_".freeze
    PROCESS_TIME_SUPPORTED = (RUBY_VERSION >= "2.1.0")
    EMPTY_OPTIONS = {}.freeze

    private_constant :NEW_LINE, :ESC_NEW_LINE, :COMMA, :PIPE, :DOT,
      :DOUBLE_COLON, :UNDERSCORE, :EMPTY_OPTIONS

    def format_service_check(name, status, opts=EMPTY_OPTIONS)
      sc_string = "_sc|#{name}|#{status}".dup

      SC_OPT_KEYS.each do |key, shorthand_key|
        next unless opts[key]

        if key == :tags
          if tags_string = tags_as_string(opts)
            sc_string << "|##{tags_string}"
          end
        elsif key == :message
          message = remove_pipes(opts[:message])
          escaped_message = escape_service_check_message(message)
          sc_string << "|m:#{escaped_message}"
        else
          value = remove_pipes(opts[key])
          sc_string << "|#{shorthand_key}#{value}"
        end
      end
      sc_string
    end

    def format_event(title, text, opts=EMPTY_OPTIONS)
      escaped_title = escape_event_content(title)
      escaped_text = escape_event_content(text)
      event_string_data = "_e{#{escaped_title.length},#{escaped_text.length}}:#{escaped_title}|#{escaped_text}".dup

      # We construct the string to be sent by adding '|key:value' parts to it when needed
      # All pipes ('|') in the metadata are removed. Title and Text can keep theirs
      OPTS_KEYS.each do |key, shorthand_key|
        if key != :tags && opts[key]
          value = remove_pipes(opts[key])
          event_string_data << "|#{shorthand_key}:#{value}"
        end
      end

      # Tags are joined and added as last part to the string to be sent
      if tags_string = tags_as_string(opts)
        event_string_data << "|##{tags_string}"
      end

      raise "Event #{title} payload is too big (more that 8KB), event discarded" if event_string_data.length > MAX_EVENT_SIZE
      event_string_data
    end

    def tags_as_string(opts)
      if tag_arr = opts[:tags]
        tag_arr = tag_arr.map { |tag| escape_tag_content(tag) }
        tag_arr = tags + tag_arr # @tags are normalized when set, so not need to normalize them again
      else
        tag_arr = tags
      end
      tag_arr.join(COMMA) unless tag_arr.empty?
    end

    def escape_event_content(msg)
      msg.gsub NEW_LINE, ESC_NEW_LINE
    end

    def escape_tag_content(tag)
      tag = remove_pipes(tag.to_s)
      tag.delete! COMMA
      tag
    end

    def remove_pipes(msg)
      msg.delete PIPE
    end

    def escape_service_check_message(msg)
      escape_event_content(msg).gsub('m:'.freeze, 'm\:'.freeze)
    end

    def send_stats(stat, delta, type, opts=EMPTY_OPTIONS)
      sample_rate = opts[:sample_rate] || 1
      if sample_rate == 1 or rand < sample_rate
        full_stat = ''.dup
        full_stat << @prefix if @prefix

        stat = stat.is_a?(String) ? stat.dup : stat.to_s
        # Replace Ruby module scoping with '.' and reserved chars (: | @) with underscores.
        stat.gsub!(DOUBLE_COLON, DOT)
        stat.tr!(':|@'.freeze, UNDERSCORE)
        full_stat << stat

        full_stat << ':'.freeze
        full_stat << delta.to_s
        full_stat << PIPE
        full_stat << type

        unless sample_rate == 1
          full_stat << PIPE
          full_stat << '@'.freeze
          full_stat << sample_rate.to_s
        end

        if tags_string = tags_as_string(opts)
          full_stat << PIPE
          full_stat << '#'.freeze
          full_stat << tags_string
        end

        send_stat(full_stat)
      end
    end

    def send_stat(message)
      if @batch.open?
        @batch.add message
      else
        @connection.write(message)
      end
    end
  end
end
