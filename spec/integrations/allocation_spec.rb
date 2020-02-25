# frozen_string_literal: true

require 'spec_helper'

describe 'Allocations and garbage collection' do
  before do
    skip 'Ruby too old' if RUBY_VERSION < '2.3.0'
  end

  let(:socket) { FakeUDPSocket.new }

  subject do
    Datadog::Statsd.new('localhost', 1234,
      namespace: namespace,
      sample_rate: sample_rate,
      tags: tags,
      logger: logger,
      telemetry_flush_interval: -1,
    )
  end

  let(:namespace) { 'sample_ns' }
  let(:sample_rate) { nil }
  let(:tags) { %w[abc def] }
  let(:logger) do
    Logger.new(log).tap do |logger|
      logger.level = Logger::INFO
    end
  end
  let(:log) { StringIO.new }

  before do
    allow(Socket).to receive(:new).and_return(socket)
    allow(UDPSocket).to receive(:new).and_return(socket)
    # initializing statsd so it does not count in allocations
    subject.increment('foobar')
  end

  it 'produces low amounts of garbage for increment' do
    expect do
      subject.increment('foobar')
    end.to make_allocations(18)
  end

  it 'produces low amounts of garbage for timing' do
    expect do
      subject.time('foobar') { 1111 }
    end.to make_allocations(18)
  end

  context 'without telemetry' do
    subject do
      Datadog::Statsd.new('localhost', 1234,
        namespace: namespace,
        sample_rate: sample_rate,
        tags: tags,
        logger: logger,
        disable_telemetry: true,
      )
    end

    it 'produces even lower amounts of garbage for increment' do
      expect do
        subject.increment('foobar')
      end.to make_allocations(8)
    end

    it 'produces even lower amounts of garbage for time' do
      expect do
        subject.time('foobar') { 1111 }
      end.to make_allocations(8)
    end
  end
end