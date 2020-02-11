# frozen_string_literal: true
require 'time'

module Datadog
  class Statsd
    class Telemetry
      attr_accessor :metrics
      attr_accessor :events
      attr_accessor :service_checks
      attr_accessor :bytes_sent
      attr_accessor :bytes_dropped
      attr_accessor :packets_sent
      attr_accessor :packets_dropped
      attr_reader   :estimate_max_size

      def initialize(disabled, tags, flush_interval)
        @disabled = disabled
        @tags = tags
        @flush_interval = flush_interval
        reset

        # estimate_max_size is an estimation or the maximum size of the
        # telemetry payload. Since we don't want our packet to go over
        # 'max_buffer_bytes', we have to adjust with the size of the telemetry
        # (and any tags used). The telemetry payload size will change depending
        # on the actual value of metrics: metrics received, packet dropped,
        # etc. This is why we add a 63bytes margin: 9 bytes for each of the 7
        # telemetry metrics.
        @estimate_max_size = @disabled ? 0 : flush().length + 9 * 7
      end

      def reset
        @metrics = 0
        @events = 0
        @service_checks = 0
        @bytes_sent = 0
        @bytes_dropped = 0
        @packets_sent = 0
        @packets_dropped = 0
        @next_flush_time = Time.now.to_i + @flush_interval
      end

      def flush?
        if @next_flush_time < Time.now.to_i
          return true
        end
        return false
      end

      def flush
        return '' if @disabled

        # using shorthand syntax to reduce the garbage collection
        return %Q(
datadog.dogstatsd.client.metrics:#{@metrics}|#{COUNTER_TYPE}|##{@tags}
datadog.dogstatsd.client.events:#{@events}|#{COUNTER_TYPE}|##{@tags}
datadog.dogstatsd.client.service_checks:#{@service_checks}|#{COUNTER_TYPE}|##{@tags}
datadog.dogstatsd.client.bytes_sent:#{@bytes_sent}|#{COUNTER_TYPE}|##{@tags}
datadog.dogstatsd.client.bytes_dropped:#{@bytes_dropped}|#{COUNTER_TYPE}|##{@tags}
datadog.dogstatsd.client.packets_sent:#{@packets_sent}|#{COUNTER_TYPE}|##{@tags}
datadog.dogstatsd.client.packets_dropped:#{@packets_dropped}|#{COUNTER_TYPE}|##{@tags})
      end
    end
  end
end
