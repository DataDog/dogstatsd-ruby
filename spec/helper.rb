require 'bundler/setup'

if RUBY_VERSION > "2.0"
  require 'single_cov'
  SingleCov.setup :minitest
end

require 'minitest/autorun'
require 'mocha/minitest'
require 'faker'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'datadog/statsd'
require 'logger'

class FakeUDPSocket
  def initialize
    @buffer = []
  end

  def send(message, *)
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
end
