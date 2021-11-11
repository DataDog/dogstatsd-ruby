module Datadog
  class Statsd
    class ConnectionCfg
      attr_reader :host
      attr_reader :port
      attr_reader :socket_path
      attr_reader :transport_type

      def initialize(host: nil, port: nil, socket_path: nil)
        initialize_with_constructor_args(host: host, port: port, socket_path: socket_path) ||
          initialize_with_env_vars ||
          initialize_with_defaults
      end

      def make_connection(**params)
        case @transport_type
        when :udp
          UDPConnection.new(@host, @port, **params)
        when :uds
          UDSConnection.new(@socket_path, **params)
        end
      end

      private

      DEFAULT_HOST = '127.0.0.1'
      DEFAULT_PORT = 8125

      def initialize_with_constructor_args(host: nil, port: nil, socket_path: nil)
        try_initialize_with(host: host, port: port, socket_path: socket_path,
          not_both_error_message: 
            "Both UDP: (host/port #{host}:#{port}) and UDS (socket_path #{socket_path}) " +
            "constructor arguments were given. Use only one or the other.",
          )
      end

      def initialize_with_env_vars()
        try_initialize_with(
          host: ENV['DD_AGENT_HOST'],
          port: ENV['DD_DOGSTATSD_PORT'] && ENV['DD_DOGSTATSD_PORT'].to_i,
          socket_path: ENV['DD_DOGSTATSD_SOCKET'],
          not_both_error_message:
            "Both UDP (DD_AGENT_HOST/DD_DOGSTATSD_PORT #{ENV['DD_AGENT_HOST']}:#{ENV['DD_DOGSTATSD_PORT']}) " +
            "and UDS (DD_DOGSTATSD_SOCKET #{ENV['DD_DOGSTATSD_SOCKET']}) environment variables are set. " +
            "Set only one or the other." %
            [ENV['DD_AGENT_HOST'], ENV['DD_DOGSTATSD_PORT'], ENV['DD_DOGSTATSD_SOCKET']])
      end

      def initialize_with_defaults()
        try_initialize_with(host: DEFAULT_HOST, port: DEFAULT_PORT)
      end

      def try_initialize_with(host: nil, port: nil, socket_path: nil, not_both_error_message: "")
        if (host || port) && socket_path
          raise ArgumentError, not_both_error_message
        end

        if host || port 
          @host = host || DEFAULT_HOST
          @port = port || DEFAULT_PORT
          @socket_path = nil
          @transport_type = :udp
          return true
        elsif socket_path
          @host = nil
          @port = nil
          @socket_path = socket_path
          @transport_type = :uds
          return true
        end

        return false
      end
    end
  end
end
