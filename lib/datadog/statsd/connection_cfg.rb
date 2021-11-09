module Datadog
  class Statsd
    class ConnectionCfg
      attr_reader :host
      attr_reader :port
      attr_reader :socket_path
      attr_reader :transport_type

      DEFAULT_HOST = '127.0.0.1'
      DEFAULT_PORT = 8125

      def initialize(host: nil, port: nil, socket_path: nil)
        initialize_with_constructor_args(host, port, socket_path) || initialize_with_env_vars || initialize_with_defaults
      end

      def initialize_with_constructor_args(host, port, socket_path)
        try_initialize_with(host, port, socket_path,
          "Both host/port and socket_path constructor arguments are set.  Set only one or the other.",
          )
      end

      def initialize_with_env_vars()
        try_initialize_with(
          ENV['DD_AGENT_HOST'],
          ENV['DD_DOGSTATSD_PORT'].nil? ? nil : ENV['DD_DOGSTATSD_PORT'].to_i,
          ENV['DD_DOGSTATSD_SOCKET'],
          "Both $DD_AGENT_HOST/$DD_DOGSTATSD_PORT and $DD_DOGSTATSD_SOCKET are set.  Set only one or the other.",
          )
      end

      def initialize_with_defaults()
        try_initialize_with(DEFAULT_HOST, DEFAULT_PORT, nil, "")
      end

      def try_initialize_with(host, port, socket_path, not_both_error_message)
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

      def make_connection(**params)
        case @transport_type
        when :udp
          UDPConnection.new(@host, @port, **params)
        when :uds
          UDSConnection.new(@socket_path, **params)
        end
      end
    end
  end
end
