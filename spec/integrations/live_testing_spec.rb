# frozen_string_literal: true

require 'spec_helper'

describe 'Live testing' do
  before do
    skip('No live testing') unless ENV['LIVE']
  end

  context 'with a real UDP socket' do
    it 'should actually send stuff over the socket' do
      socket = UDPSocket.new
      host, port = 'localhost', 12345
      socket.bind(host, port)

      Datadog::Statsd.open(host, port) do |statsd|
        statsd.increment('foobar')
        statsd.count('swag', 1337)
        statsd.timing('work', 2450)
        statsd.gauge('capacity', 85.2)
      end

      expect(socket.recvfrom(64).first).to eq 'foobar:1|c'
      expect(socket.recvfrom(64).first).to eq 'swag:1337|c'
      expect(socket.recvfrom(64).first).to eq 'work:2450|ms'
      expect(socket.recvfrom(64).first).to eq 'capacity:85.2|g'
    end
  end
end
