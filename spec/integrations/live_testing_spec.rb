# frozen_string_literal: true

require 'spec_helper'

describe 'Live testing' do
  before do
    skip('No live testing') unless ENV['LIVE']
  end

  context 'with a real UDP socket' do
    let(:host) do
      'localhost'
    end

    let(:port) do
      12345
    end

    let(:server_socket) do
      UDPSocket.new
    end

    before do
      server_socket.bind(host, port)
    end

    after do
      server_socket.close
    end

    it 'should actually send stuff to the server socket' do
      Datadog::Statsd.open(host, port) do |statsd|
        statsd.increment('foobar')
        statsd.flush
        statsd.count('swag', 1337)
        statsd.flush
        statsd.timing('work', 2450)
        statsd.flush
        statsd.gauge('capacity', 85.2)
        statsd.flush
      end

      expect(server_socket.recvfrom(64).first).to eq 'foobar:1|c'
      expect(server_socket.recvfrom(64).first).to eq 'swag:1337|c'
      expect(server_socket.recvfrom(64).first).to eq 'work:2450|ms'
      expect(server_socket.recvfrom(64).first).to eq 'capacity:85.2|g'
    end
  end
end
