# frozen_string_literal: true
require 'socket'

require_relative 'statsd/version'
require_relative 'statsd/telemetry'
require_relative 'statsd/udp_connection'
require_relative 'statsd/uds_connection'
require_relative 'statsd/batch'

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
    # Create a dictionary to assign a key to every parameter's name, except for tags (treated differently)
    # Goal: Simple and fast to add some other parameters
    OPTS_KEYS = {
      date_happened:    :d,
      hostname:         :h,
      aggregation_key:  :k,
      priority:         :p,
      source_type_name: :s,
      alert_type:       :t,
    }.freeze

    # Service check options
    SC_OPT_KEYS = {
      timestamp: 'd:',
      hostname:  'h:',
      tags:      '#',
      message:   'm:',
    }.freeze

    OK       = 0
    WARNING  = 1
    CRITICAL = 2
    UNKNOWN  = 3

    DEFAULT_BUFFER_SIZE = 8 * 1_024
    MAX_EVENT_SIZE = 8 * 1_024
    # minimum flush interval for the telemetry in seconds
    DEFAULT_TELEMETRY_FLUSH_INTERVAL = 10

    COUNTER_TYPE = 'c'
    GAUGE_TYPE = 'g'
    HISTOGRAM_TYPE = 'h'
    DISTRIBUTION_TYPE = 'd'
    TIMING_TYPE = 'ms'
    SET_TYPE = 's'

    # A namespace to prepend to all statsd calls. Defaults to no namespace.
    attr_reader :namespace

    # Global tags to be added to every statsd call. Defaults to no tags.
    attr_reader :tags

    # Buffer containing the statsd message before they are sent in batch
    attr_reader :buffer

    # Maximum buffer size in bytes before it is flushed
    attr_reader :max_buffer_bytes

    # Default sample rate
    attr_reader :sample_rate

    # Connection
    attr_reader :connection

    # @param [String] host your statsd host
    # @param [Integer] port your statsd port
    # @option [String] namespace set a namespace to be prepended to every metric name
    # @option [Array<String>|Hash] tags tags to be added to every metric
    # @option [Logger] logger for debugging
    # @option [Integer] max_buffer_bytes max bytes to buffer when using #batch
    # @option [String] socket_path unix socket path
    # @option [Float] default sample rate if not overridden
    def initialize(
      host = nil,
      port = nil,
      namespace: nil,
      tags: nil,
      max_buffer_bytes: DEFAULT_BUFFER_SIZE,
      socket_path: nil,
      logger: nil,
      sample_rate: nil,
      disable_telemetry: false,
      telemetry_flush_interval: DEFAULT_TELEMETRY_FLUSH_INTERVAL
    )
      unless tags.nil? || tags.is_a?(Array) || tags.is_a?(Hash)
        raise ArgumentError, 'tags must be a Array<String> or a Hash'
      end

      tags = tag_hash_to_array(tags) if tags.is_a?(Hash)
      @tags = (tags || []).compact.map! do |tag|
        escape_tag_content(tag)
      end

      # append the entity id to tags if DD_ENTITY_ID env var is not nil
      unless ENV.fetch('DD_ENTITY_ID', nil).nil?
        dd_entity = escape_tag_content(ENV.fetch('DD_ENTITY_ID', nil))
        @tags << 'dd.internal.entity_id:' + dd_entity
      end

      # init telemetry
      transport_type = socket_path.nil? ? 'udp': 'uds'
      telemetry_tags = (["client:ruby", "client_version:#{VERSION}", "client_transport:#{transport_type}"] + @tags).join(COMMA).freeze
      @telemetry = Telemetry.new(disable_telemetry, telemetry_tags, telemetry_flush_interval)

      if socket_path.nil?
        @connection = UDPConnection.new(host, port, logger, @telemetry)
      else
        @connection = UDSConnection.new(socket_path, logger, @telemetry)
      end
      @logger = logger

      @namespace = namespace
      @prefix = @namespace ? "#{@namespace}.".freeze : nil

      @sample_rate = sample_rate

      # we reduce max_buffer_bytes by a the rough estimate of the telemetry payload
      @batch = Batch.new(@connection, (max_buffer_bytes - @telemetry.estimate_max_size))
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
    def increment(stat, opts = EMPTY_OPTIONS)
      opts = { sample_rate: opts } if opts.is_a?(Numeric)
      incr_value = opts.fetch(:by, 1)
      count(stat, incr_value, opts)
    end

    # Sends a decrement (count = -1) for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @option opts [Numeric] :by decrement value, default 1
    # @see #count
    def decrement(stat, opts = EMPTY_OPTIONS)
      opts = { sample_rate: opts } if opts.is_a?(Numeric)
      decr_value = - opts.fetch(:by, 1)
      count(stat, decr_value, opts)
    end

    # Sends an arbitrary count for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Integer] count count
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    def count(stat, count, opts = EMPTY_OPTIONS)
      opts = { sample_rate: opts } if opts.is_a?(Numeric)
      send_stats(stat, count, COUNTER_TYPE, opts)
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
    def gauge(stat, value, opts = EMPTY_OPTIONS)
      opts = { sample_rate: opts } if opts.is_a?(Numeric)
      send_stats(stat, value, GAUGE_TYPE, opts)
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
    def histogram(stat, value, opts = EMPTY_OPTIONS)
      send_stats(stat, value, HISTOGRAM_TYPE, opts)
    end

    # Sends a value to be tracked as a distribution to the statsd server.
    #
    # @param [String] stat stat name.
    # @param [Numeric] value distribution value.
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @example Report the current user count:
    #   $statsd.distribution('user.count', User.count)
    def distribution(stat, value, opts = EMPTY_OPTIONS)
      send_stats(stat, value, DISTRIBUTION_TYPE, opts)
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
    def timing(stat, ms, opts = EMPTY_OPTIONS)
      opts = { sample_rate: opts } if opts.is_a?(Numeric)
      send_stats(stat, ms, TIMING_TYPE, opts)
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
    def time(stat, opts = EMPTY_OPTIONS)
      opts = { sample_rate: opts } if opts.is_a?(Numeric)
      start = if PROCESS_TIME_SUPPORTED
                Process.clock_gettime(Process::CLOCK_MONOTONIC) # uncovered
              else
                Time.now.to_f # uncovered
              end
      yield
    ensure
      finished =  if PROCESS_TIME_SUPPORTED
                    Process.clock_gettime(Process::CLOCK_MONOTONIC) # uncovered
                  else
                    Time.now.to_f # uncovered
                  end

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
    def set(stat, value, opts = EMPTY_OPTIONS)
      opts = { sample_rate: opts } if opts.is_a?(Numeric)
      send_stats(stat, value, SET_TYPE, opts)
    end

    # This method allows you to send custom service check statuses.
    #
    # @param [String] name Service check name
    # @param [String] status Service check status.
    # @param [Hash] opts the additional data about the service check
      # @option opts [Integer, String, nil] :timestamp (nil) Assign a timestamp to the service check. Default is now when none
      # @option opts [String, nil] :hostname (nil) Assign a hostname to the service check.
      # @option opts [Array<String>, nil] :tags (nil) An array of tags
      # @option opts [String, nil] :message (nil) A message to associate with this service check status
    # @example Report a critical service check status
    #   $statsd.service_check('my.service.check', Statsd::CRITICAL, :tags=>['urgent'])
    def service_check(name, status, opts = EMPTY_OPTIONS)
      @telemetry.service_checks += 1
      send_stat(format_service_check(name, status, opts))
    end

    # This end point allows you to post events to the stream. You can tag them, set priority and even aggregate them with other events.
    #
    # Aggregation in the stream is made on hostname/event_type/source_type/aggregation_key.
    # If there's no event type, for example, then that won't matter;
    # it will be grouped with other events that don't have an event type.
    #
    # @param [String] title Event title
    # @param [String] text Event text. Supports newlines (+\n+)
    # @param [Hash] opts the additional data about the event
    # @option opts [Integer, String, nil] :date_happened (nil) Assign a timestamp to the event. Default is now when none
    # @option opts [String, nil] :hostname (nil) Assign a hostname to the event.
    # @option opts [String, nil] :aggregation_key (nil) Assign an aggregation key to the event, to group it with some others
    # @option opts [String, nil] :priority ('normal') Can be "normal" or "low"
    # @option opts [String, nil] :source_type_name (nil) Assign a source type to the event
    # @option opts [String, nil] :alert_type ('info') Can be "error", "warning", "info" or "success".
    # @option opts [Array<String>] :tags tags to be added to every metric
    # @example Report an awful event:
    #   $statsd.event('Something terrible happened', 'The end is near if we do nothing', :alert_type=>'warning', :tags=>['end_of_times','urgent'])
    def event(title, text, opts = EMPTY_OPTIONS)
      @telemetry.events += 1
      send_stat(format_event(title, text, opts))
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
      @batch.open do
        yield self
      end
    end

    # Close the underlying socket
    def close
      @connection.close
    end

    private

    NEW_LINE = "\n"
    ESC_NEW_LINE = '\n'
    COMMA = ','
    PIPE = '|'
    DOT = '.'
    DOUBLE_COLON = '::'
    UNDERSCORE = '_'
    PROCESS_TIME_SUPPORTED = (RUBY_VERSION >= '2.1.0')
    EMPTY_OPTIONS = {}.freeze

    private_constant :NEW_LINE, :ESC_NEW_LINE, :COMMA, :PIPE, :DOT,
      :DOUBLE_COLON, :UNDERSCORE, :EMPTY_OPTIONS

    def format_service_check(name, status, opts = EMPTY_OPTIONS)
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
          if key == :timestamp && opts[key].is_a?(Integer)
            value = opts[key]
          else
            value = remove_pipes(opts[key])
          end
          sc_string << "|#{shorthand_key}#{value}"
        end
      end
      sc_string
    end

    def format_event(title, text, opts = EMPTY_OPTIONS)
      escaped_title = escape_event_content(title)
      escaped_text = escape_event_content(text)
      event_string_data = "_e{#{escaped_title.bytesize},#{escaped_text.bytesize}}:#{escaped_title}|#{escaped_text}".dup

      # We construct the string to be sent by adding '|key:value' parts to it when needed
      # All pipes ('|') in the metadata are removed. Title and Text can keep theirs
      OPTS_KEYS.each do |key, shorthand_key|
        if key != :tags && opts[key]
          # :date_happened is the only key where the value is an Integer
          # To not break backwards compatibility, we still accept a String
          if key == :date_happened && opts[key].is_a?(Integer)
              value = opts[key]
          # All other keys only have String values
          else
              value = remove_pipes(opts[key])
          end
          event_string_data << "|#{shorthand_key}:#{value}"
        end
      end

      # Tags are joined and added as last part to the string to be sent
      if tags_string = tags_as_string(opts)
        event_string_data << "|##{tags_string}"
      end

      if event_string_data.bytesize > MAX_EVENT_SIZE
        raise "Event #{title} payload is too big (more that 8KB), event discarded"
      end
      event_string_data
    end

    def tags_as_string(opts)
      if tag_arr = opts[:tags]
        tag_arr = tag_hash_to_array(tag_arr) if tag_arr.is_a?(Hash)
        tag_arr = tag_arr.map do |tag|
          escape_tag_content(tag)
        end
        tag_arr = tags + tag_arr # @tags are normalized when set, so not need to normalize them again
      else
        tag_arr = tags
      end
      tag_arr.join(COMMA) unless tag_arr.empty?
    end

    def tag_hash_to_array(tag_hash)
      tag_hash.to_a.map do |pair|
        pair.compact.join(':')
      end
    end

    def escape_event_content(message)
      message.gsub(NEW_LINE, ESC_NEW_LINE)
    end

    def escape_tag_content(tag)
      tag = remove_pipes(tag.to_s)
      tag.delete!(COMMA)
      tag
    end

    def remove_pipes(message)
      message.delete(PIPE)
    end

    def escape_service_check_message(message)
      escape_event_content(message).gsub('m:', 'm\:')
    end

    def send_stats(stat, delta, type, opts = EMPTY_OPTIONS)
      @telemetry.metrics += 1
      sample_rate = opts[:sample_rate] || @sample_rate || 1
      if sample_rate == 1 || rand <= sample_rate
        full_stat = ''.dup
        full_stat << @prefix if @prefix

        stat = stat.is_a?(String) ? stat.dup : stat.to_s
        # Replace Ruby module scoping with '.' and reserved chars (: | @) with underscores.
        stat.gsub!(DOUBLE_COLON, DOT)
        stat.tr!(':|@', UNDERSCORE)
        full_stat << stat

        full_stat << ':'
        full_stat << delta.to_s
        full_stat << PIPE
        full_stat << type

        unless sample_rate == 1
          full_stat << PIPE
          full_stat << '@'
          full_stat << sample_rate.to_s
        end

        if tags_string = tags_as_string(opts)
          full_stat << PIPE
          full_stat << '#'
          full_stat << tags_string
        end
        send_stat(full_stat)
      end
    end

    def send_stat(message)
      @batch.open? ? @batch.add(message) : @connection.write(message)
    end
  end
end
