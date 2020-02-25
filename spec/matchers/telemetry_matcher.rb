require 'rspec/expectations'

RSpec::Matchers.define :eq_with_telemetry do |expected, telemetry_options|
  telemetry_options ||= {}

  def text_with_telemetry(text, metrics: 1, events: 0, service_checks: 0, bytes_sent: 0, bytes_dropped:0, packets_sent: 0, packets_dropped: 0, transport: 'udp')
    [
      text,
      "datadog.dogstatsd.client.metrics:#{metrics}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.events:#{events}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.service_checks:#{service_checks}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.bytes_sent:#{bytes_sent}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.bytes_dropped:#{bytes_dropped}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.packets_sent:#{packets_sent}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
      "datadog.dogstatsd.client.packets_dropped:#{packets_dropped}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
    ].join("\n")
  end

  match do |actual|
    actual == text_with_telemetry(expected, **telemetry_options)
  end

  failure_message do |actual|
    "expected that #{actual.inspect} would be equal to #{expected.inspect} with telemetry options #{telemetry_options.inspect}"
  end
end
