require 'bundler/setup'
require 'minitest/autorun'
require 'faker'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'simplecov'
SimpleCov.start

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
