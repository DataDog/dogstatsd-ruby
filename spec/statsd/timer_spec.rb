require 'spec_helper'

describe Datadog::Statsd::Timer do
  subject do
    described_class.new(interval) do
      sleep callback_durations.next
      call_times << Time.now
    end
  end
  let(:call_times) { Queue.new }
  let(:callback_durations) do
    Enumerator.new do |y|
      loop do
        y << 0
      end
    end
  end

  describe '#start' do
    let(:interval) { 0.001 }

    # this callback_durations allows calls at an odd number of times
    # to take almost no time, whereas calls at an even number of times
    # to take at least `interval` seconds.
    let(:callback_durations) do
      Enumerator.new do |y|
        loop do
          [0, interval].each do |d|
            y << d
          end
        end
      end
    end

    after do
      subject.stop
    end

    it 'starts the timer thread and calls the callback' do
      expect do
        subject.start
      end.to change { Thread.list.size }.by(1)

      # use timeout just in case call_times.pop waits forever
      Timeout.timeout(1) do
        # the first call is made after `interval` seconds
        first_call_time = call_times.pop
        # the second call is made `interval` seconds after the first call
        # and it takes `interval` seconds before Time.now is called
        second_call_time = call_times.pop
        # the third call is made immediatelly after the second call
        third_call_time = call_times.pop
        expect(second_call_time - first_call_time).to be_within(0.03).of(interval * 2)
        expect(third_call_time - second_call_time).to be_within(0.03).of(0)
      end
    end
  end

  describe '#stop' do
    let(:interval) { 15 }

    before do
      subject.start
      # sleep a little for the thread to call ConditionVariable#wait
      sleep 0.01
    end

    it 'stops the timer thread after calling the callback' do
      expect do
        # the timer should call the callback immediatelly, that is, without waiting the interval
        Timeout.timeout(1) do
          subject.stop
        end
      end.to change { Thread.list.size }.by(-1)

      expect(call_times).not_to be_empty
    end
  end
end
