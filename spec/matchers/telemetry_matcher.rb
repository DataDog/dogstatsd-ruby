require 'rspec/expectations'

RSpec::Matchers.define :eq_with_telemetry do |expected_message, telemetry_options|
  telemetry_options ||= {}

  # Appends the telemetry metrics to the metrics string passed as 'text'
  def add_telemetry(text,
                    metrics: 1,
                    events: 0,
                    service_checks: 0,
                    bytes_sent: 0,
                    bytes_dropped: 0,
                    bytes_dropped_writer: 0,
                    packets_sent: 0,
                    packets_dropped: 0,
                    packets_dropped_writer: 0,
                    transport: 'udp')
    [
      text,
      "datadog.dogstatsd.client.metrics:#{metrics}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.events:#{events}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.service_checks:#{service_checks}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.bytes_sent:#{bytes_sent}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.bytes_dropped:#{bytes_dropped}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.bytes_dropped_writer:#{bytes_dropped_writer}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.packets_sent:#{packets_sent}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.packets_dropped:#{packets_dropped}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.packets_dropped_writer:#{packets_dropped_writer}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
    ].join("\n")
  end

  define_method(:expected) do
    @expected ||= add_telemetry(expected_message, **telemetry_options)
  end

  match do |actual|
    actual == expected
  end

  diffable
end
