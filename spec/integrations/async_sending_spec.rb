require 'spec_helper'

describe 'Sending asynchronously' do
  subject do
    Datadog::Statsd::Sender.new(message_buffer).tap(&:start)
  end

  let(:message_buffer) do
    instance_double(Datadog::Statsd::MessageBuffer)
  end

  after do
    subject.stop
  end

  context 'with normal sending conditions' do
    context 'without rendez_vous' do
      it 'adds message to the buffer correctly' do
        expect(message_buffer).to receive(:add).with('message 1')
        expect(message_buffer).to receive(:add).with('message 2')
        expect(message_buffer).to receive(:add).with('message 3')

        subject.add('message 1')
        subject.add('message 2')
        subject.add('message 3')
        # add delay to be sure worker thread correctly add messages
        sleep 0.5
      end
    end

    context 'with rendez_vous' do
      it 'adds message to the buffer correctly' do
        expect(message_buffer).to receive(:add).with('message 1')
        expect(message_buffer).to receive(:add).with('message 2')
        expect(message_buffer).to receive(:add).with('message 3')

        subject.add('message 1')
        subject.add('message 2')
        subject.add('message 3')
        # add delay to be sure worker thread correctly add messages
        subject.rendez_vous
      end
    end
  end

  context 'under slow networking conditions' do
    let(:expected_messages) do
      [
        'message 1',
        'message 2',
        'message 3',
      ]
    end

    before do
      allow(message_buffer).to receive(:add) do |message|
        sleep 0.5

        if expected_messages.include?(message)
          expected_messages.delete(message)
        else
          raise "Unexpected message '#{message}'"
        end

        true
      end
    end

    context 'without rendez_vous' do
      it 'adds message to the buffer correctly' do
        subject.add('message 1')
        subject.add('message 2')
        subject.add('message 3')

        # add delay to be sure worker thread correctly add messages
        sleep 2

        expect(expected_messages).to be_empty
      end
    end

    context 'with rendez_vous' do
      it 'adds message to the buffer correctly' do
        subject.add('message 1')
        subject.add('message 2')
        subject.add('message 3')
        # add delay to be sure worker thread correctly add messages
        subject.rendez_vous

        expect(expected_messages).to be_empty
      end
    end

    context 'when asking for stop of sender in the middle' do
      context 'when joining worker' do
        it 'finishes properly and adds all the messages to the buffer' do
          subject.add('message 1')
          subject.add('message 2')
          subject.add('message 3')

          subject.stop

          expect(expected_messages).to be_empty
        end
      end

      context 'when not joining worker' do
        it 'finishes properly and adds all the messages to the buffer' do
          subject.add('message 1')
          subject.add('message 2')
          subject.add('message 3')

          subject.stop(join_worker: false)

          sleep 2

          expect(expected_messages).to be_empty
        end
      end
    end
  end
end
