# frozen_string_literal: true
require 'time'

module Datadog
  class Statsd
    class Telemetry
      attr_reader :metrics
      attr_reader :events
      attr_reader :service_checks
      attr_reader :bytes_sent
      attr_reader :bytes_dropped
      attr_reader :packets_sent
      attr_reader :packets_dropped

      # Rough estimation of maximum telemetry message size without tags
      MAX_TELEMETRY_MESSAGE_SIZE_WT_TAGS = 50 # bytes

      def initialize(flush_interval, global_tags: [], transport_type: :udp)
        @flush_interval = flush_interval
        @global_tags = global_tags
        @transport_type = transport_type
        reset

        # TODO: Karim: I don't know why but telemetry tags are serialized
        # before global tags so by refactoring this, I am keeping the same behavior
        @serialized_tags = Serialization::TagSerializer.new(
          client: 'ruby',
          client_version: VERSION,
          client_transport: transport_type,
        ).format(global_tags)
      end

      def would_fit_in?(max_buffer_payload_size)
        MAX_TELEMETRY_MESSAGE_SIZE_WT_TAGS + serialized_tags.size < max_buffer_payload_size
      end

      def reset
        @metrics = 0
        @events = 0
        @service_checks = 0
        @bytes_sent = 0
        @bytes_dropped = 0
        @packets_sent = 0
        @packets_dropped = 0
        @next_flush_time = now_in_s + @flush_interval
      end

      def sent(metrics: 0, events: 0, service_checks: 0, bytes: 0, packets: 0)
        @metrics += metrics
        @events += events
        @service_checks += service_checks

        @bytes_sent += bytes
        @packets_sent += packets
      end

      def dropped(bytes: 0, packets: 0)
        @bytes_dropped += bytes
        @packets_dropped += packets
      end

      def flush?
        @next_flush_time < now_in_s
      end

      def flush
        # using shorthand syntax to reduce the garbage collection
        %Q(
datadog.dogstatsd.client.metrics:#{@metrics}|#{COUNTER_TYPE}|##{serialized_tags}
datadog.dogstatsd.client.events:#{@events}|#{COUNTER_TYPE}|##{serialized_tags}
datadog.dogstatsd.client.service_checks:#{@service_checks}|#{COUNTER_TYPE}|##{serialized_tags}
datadog.dogstatsd.client.bytes_sent:#{@bytes_sent}|#{COUNTER_TYPE}|##{serialized_tags}
datadog.dogstatsd.client.bytes_dropped:#{@bytes_dropped}|#{COUNTER_TYPE}|##{serialized_tags}
datadog.dogstatsd.client.packets_sent:#{@packets_sent}|#{COUNTER_TYPE}|##{serialized_tags}
datadog.dogstatsd.client.packets_dropped:#{@packets_dropped}|#{COUNTER_TYPE}|##{serialized_tags})
      end

      private
      attr_reader :serialized_tags

      if Kernel.const_defined?('Process') && Process.respond_to?(:clock_gettime)
        def now_in_s
          Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
        end
      else
        def now_in_s
          Time.now.to_i
        end
      end
    end
  end
end
