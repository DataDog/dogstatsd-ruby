require 'spec_helper'

describe Datadog::Statsd do
  describe 'VERSION' do
    it 'has a version' do
      expect(Datadog::Statsd::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end
end
