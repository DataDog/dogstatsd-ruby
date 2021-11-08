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

        # Try with constructor args
        if setup_with(host, port, socket_path)
          return
        end

        # Try with env vars
        if setup_with(
            ENV['DD_AGENT_HOST'],
            ENV['DD_DOGSTATSD_PORT'].nil? ? nil : ENV['DD_DOGSTATSD_PORT'].to_i,
            ENV['DD_DOGSTATSD_SOCKET'])
          return
        end

        # Fall back to defaults
        setup_with(DEFAULT_HOST, DEFAULT_PORT, nil)
      end

      # set up the configuration with the given values; this is a helper for #initialize
      def setup_with(host, port, socket_path)
        if (host || port) && socket_path
          raise ArgumentError, "Do not set both host/port and socket_path"
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
