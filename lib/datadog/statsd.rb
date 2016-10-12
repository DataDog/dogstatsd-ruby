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
#   statsd = Datadog::Statsd.new 'localhost', 8125, :tags => 'tag1:true'
module Datadog
  class Statsd

    DEFAULT_HOST = '127.0.0.1'
    DEFAULT_PORT = 8125

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

    # A namespace to prepend to all statsd calls. Defaults to no namespace.
    attr_reader :namespace

    # StatsD host. Defaults to 127.0.0.1.
    attr_reader :host

    # StatsD port. Defaults to 8125.
    attr_reader :port

    # Global tags to be added to every statsd call. Defaults to no tags.
    attr_reader :tags

    # Buffer containing the statsd message before they are sent in batch
    attr_reader :buffer

    # Maximum number of metrics in the buffer before it is flushed
    attr_accessor :max_buffer_size

    class << self
      # Set to a standard logger instance to enable debug logging.
      attr_accessor :logger
    end

    # Return the current version of the library.
    def self.VERSION
      "2.0.0"
    end

    # @param [String] host your statsd host
    # @param [Integer] port your statsd port
    # @option opts [String] :namespace set a namespace to be prepended to every metric name
    # @option opts [Array<String>] :tags tags to be added to every metric
    def initialize(host = DEFAULT_HOST, port = DEFAULT_PORT, opts = {}, max_buffer_size=50)
      self.host, self.port = host, port
      @prefix = nil
      @socket = UDPSocket.new
      self.namespace = opts[:namespace]
      self.tags = opts[:tags]
      @buffer = Array.new
      self.max_buffer_size = max_buffer_size
      alias :send_stat :send_to_socket
    end

    def namespace=(namespace) #:nodoc:
      @namespace = namespace
      @prefix = namespace.nil? ? nil : "#{namespace}.".freeze
    end

    def host=(host) #:nodoc:
      @host = host || DEFAULT_HOST
    end

    def port=(port) #:nodoc:
      @port = port || DEFAULT_PORT
    end

    def tags=(tags) #:nodoc:
      raise ArgumentError, 'tags must be a Array<String>' unless tags.nil? or tags.is_a? Array
      @tags = (tags || []).map {|tag| escape_tag_content(tag)}
    end

    # Sends an increment (count = 1) for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @see #count
    def increment(stat, opts={})
      count stat, 1, opts
    end

    # Sends a decrement (count = -1) for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    # @see #count
    def decrement(stat, opts={})
      count stat, -1, opts
    end

    # Sends an arbitrary count for the given stat to the statsd server.
    #
    # @param [String] stat stat name
    # @param [Integer] count count
    # @param [Hash] opts the options to create the metric with
    # @option opts [Numeric] :sample_rate sample rate, 1 for always
    # @option opts [Array<String>] :tags An array of tags
    def count(stat, count, opts={})
      send_stats stat, count, :c, opts
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
    def gauge(stat, value, opts={})
      send_stats stat, value, :g, opts
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
    def histogram(stat, value, opts={})
      send_stats stat, value, :h, opts
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
    def timing(stat, ms, opts={})
      send_stats stat, ms, :ms, opts
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
    def time(stat, opts={})
      start = Time.now
      result = yield
      time_since(stat, start, opts)
      result
    rescue
      time_since(stat, start, opts)
      raise
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
    def set(stat, value, opts={})
      send_stats stat, value, :s, opts
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
    def service_check(name, status, opts={})
      service_check_string = format_service_check(name, status, opts)
      send_to_socket service_check_string
    end

    def format_service_check(name, status, opts={})
      sc_string = "_sc|#{name}|#{status}"

      SC_OPT_KEYS.each do |key, shorthand_key|
        next unless opts[key]

        if key == :tags
          tags = opts[:tags].map {|tag| escape_tag_content(tag) }
          tags = "#{tags.join(COMMA)}" unless tags.empty?
          sc_string << "|##{tags}"
        elsif key == :message
          message = remove_pipes(opts[:message])
          escaped_message = escape_service_check_message(message)
          sc_string << "|m:#{escaped_message}"
        else
          value = remove_pipes(opts[key])
          sc_string << "|#{shorthand_key}#{value}"
        end
      end
      return sc_string
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
    def event(title, text, opts={})
      event_string = format_event(title, text, opts)
      raise "Event #{title} payload is too big (more that 8KB), event discarded" if event_string.length > 8 * 1024

      send_to_socket event_string
    end

    # Send several metrics in the same UDP Packet
    # They will be buffered and flushed when the block finishes
    #
    # @example Send several metrics in one packet:
    #   $statsd.batch do |s|
    #      s.gauge('users.online',156)
    #      s.increment('page.views')
    #    end
    def batch()
      alias :send_stat :send_to_buffer
      yield self
      flush_buffer
      alias :send_stat :send_to_socket
    end

    def format_event(title, text, opts={})
      escaped_title = escape_event_content(title)
      escaped_text = escape_event_content(text)
      event_string_data = "_e{#{escaped_title.length},#{escaped_text.length}}:#{escaped_title}|#{escaped_text}"

      # We construct the string to be sent by adding '|key:value' parts to it when needed
      # All pipes ('|') in the metadata are removed. Title and Text can keep theirs
      OPTS_KEYS.each do |key, shorthand_key|
        if key != :tags && opts[key]
          value = remove_pipes(opts[key])
          event_string_data << "|#{shorthand_key}:#{value}"
        end
      end

      # Tags are joined and added as last part to the string to be sent
      full_tags = (tags + (opts[:tags] || [])).map {|tag| escape_tag_content(tag) }
      unless full_tags.empty?
        event_string_data << "|##{full_tags.join(COMMA)}"
      end

      raise "Event #{title} payload is too big (more that 8KB), event discarded" if event_string_data.length > 8192 # 8 * 1024 = 8192
      return event_string_data
    end

    private

    NEW_LINE = "\n".freeze
    ESC_NEW_LINE = "\\n".freeze
    COMMA = ",".freeze
    BLANK = "".freeze
    PIPE = "|".freeze
    DOT = ".".freeze
    DOUBLE_COLON = "::".freeze
    UNDERSCORE = "_".freeze

    private_constant :NEW_LINE, :ESC_NEW_LINE, :COMMA, :BLANK, :PIPE, :DOT,
      :DOUBLE_COLON, :UNDERSCORE

    def escape_event_content(msg)
      msg.gsub NEW_LINE, ESC_NEW_LINE
    end

    def escape_tag_content(tag)
      remove_pipes(tag).gsub COMMA, BLANK
    end

    def remove_pipes(msg)
      msg.gsub PIPE, BLANK
    end

    def escape_service_check_message(msg)
      escape_event_content(msg).gsub('m:'.freeze, 'm\:'.freeze)
    end

    def time_since(stat, start, opts)
      timing(stat, ((Time.now - start) * 1000).round, opts)
    end

    def send_stats(stat, delta, type, opts={})
      sample_rate = opts[:sample_rate] || 1
      if sample_rate == 1 or rand < sample_rate
        # Replace Ruby module scoping with '.' and reserved chars (: | @) with underscores.
        stat = stat.to_s.gsub(DOUBLE_COLON, DOT).tr(':|@'.freeze, UNDERSCORE)
        rate = "|@#{sample_rate}" unless sample_rate == 1
        ts = (tags || []) + (opts[:tags] || []).map {|tag| escape_tag_content(tag)}
        tags = "|##{ts.join(COMMA)}" unless ts.empty?
        send_stat "#{@prefix}#{stat}:#{delta}|#{type}#{rate}#{tags}"
      end
    end

    def send_to_buffer(message)
      @buffer << message
      if @buffer.length >= @max_buffer_size
        flush_buffer
      end
    end

    def flush_buffer()
      send_to_socket(@buffer.join(NEW_LINE))
      @buffer = Array.new
    end

    def send_to_socket(message)
      self.class.logger.debug { "Statsd: #{message}" } if self.class.logger
      @socket.send(message, 0, @host, @port)
    rescue => boom
      self.class.logger.error { "Statsd: #{boom.class} #{boom}" } if self.class.logger
      nil
    end

    # Close the underlying socket
    def close()
      @socket.close
    end
  end
end
