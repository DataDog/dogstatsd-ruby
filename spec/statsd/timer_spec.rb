require 'spec_helper'

describe Datadog::Statsd::Timer do
  subject do
    described_class.new(interval) do
      queue << Time.now
    end
  end
  let(:queue) { Queue.new }

  describe '#start' do
    let(:interval) { 0.001 }

    after do
      subject.stop
    end

    it 'starts the timer thread and calls the callback' do
      expect do
        subject.start
      end.to change { Thread.list.size }.by(1)

      # the callback should be called in a short time
      Timeout.timeout(1) do
        queue.pop
      end
    end
  end

  describe '#stop' do
    let(:interval) { 15 }

    before do
      subject.start
      # sleep a little for the thread to call ConditionVariable#wait
      sleep 0.000001
    end

    it 'stops the timer thread after calling the callback' do
      expect do
        # the timer should call the callback immediatelly, that is, without waiting the interval
        Timeout.timeout(1) do
          subject.stop
        end
      end.to change { Thread.list.size }.by(-1)

      expect(queue).not_to be_empty
    end
  end
end
