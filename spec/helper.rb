require 'bundler/setup'

if RUBY_VERSION > "2.0"
  require 'single_cov'
  SingleCov.setup :minitest
end

require "minitest/matchers"
require 'minitest/autorun'
require 'mocha/minitest'
require 'faker'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'datadog/statsd'
require 'logger'

class TelemetryMatcher

  attr_accessor :text

  def initialize(text, metrics, events, service_checks, bytes_sent, bytes_dropped, packets_sent, packets_dropped, transport)
    telemetry = ["datadog.dogstatsd.client.metrics:#{metrics}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
                 "datadog.dogstatsd.client.events:#{events}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
                 "datadog.dogstatsd.client.service_checks:#{service_checks}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
                 "datadog.dogstatsd.client.bytes_sent:#{bytes_sent}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
                 "datadog.dogstatsd.client.bytes_dropped:#{bytes_dropped}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
                 "datadog.dogstatsd.client.packets_sent:#{packets_sent}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
                 "datadog.dogstatsd.client.packets_dropped:#{packets_dropped}|c|#client:ruby,client_version:#{Datadog::Statsd::VERSION},client_transport:#{transport}",
    ].join("\n")
    @text = "#{text}\n#{telemetry}"
    @last_compare = ''
  end

  def length
    @text.length
  end

  def matches?(subject)
    @last_compare = subject
    subject == @text
  end

  def failure_message_for_should
    %(expected:
#{@text}
got:
#{@last_compare}
)
  end
end

def equal_with_telemetry(text, metrics: 1, events: 0, service_checks: 0, bytes_sent: 0, bytes_dropped:0, packets_sent: 0, packets_dropped: 0, transport: "udp")
  TelemetryMatcher.new(text, metrics, events, service_checks, bytes_sent, bytes_dropped, packets_sent, packets_dropped, transport)
end
MiniTest::Unit::TestCase.register_matcher :equal_with_telemetry, :equal_with_telemetry

class FakeUDPSocket
  def initialize
    @buffer = []
    @error_on_send = nil
  end

  def send(message, *)
    raise @error_on_send if @error_on_send
    @buffer.push [message]
  end

  def recv
    @buffer.shift
  end

  def to_s
    inspect
  end

  def inspect
    "<FakeUDPSocket: #{@buffer.inspect}>"
  end

  def error_on_send(err)
    @error_on_send = err
  end
end
