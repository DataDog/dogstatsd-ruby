require 'spec_helper'

describe Datadog::Statsd::Serialization::ServiceCheckSerializer do
  subject do
    described_class.new(global_tags: global_tags)
  end

  let(:global_tags) do
    double('global tags')
  end

  describe '#format' do
    before do
      allow(Datadog::Statsd::Serialization::TagSerializer)
        .to receive(:new)
        .with(global_tags)
        .and_return(tag_serializer)
    end

    let(:tag_serializer) do
      instance_double(Datadog::Statsd::Serialization::TagSerializer,
        format: nil
      )
    end

    it 'serializes the service check correctly' do
      expect(subject.format('windmill', 'grinding')).to eq '_sc|windmill|grinding'
    end

    context 'when there are global tags' do
      before do
        allow(tag_serializer).to receive(:format).
        with(nil).
        and_return('a-global-tag,another-global')
      end

      it 'serializes the event correctly with global tags' do
        expect(subject.format('windmill', 'grinding'))
          .to eq '_sc|windmill|grinding|#a-global-tag,another-global'
      end
    end

    context 'when having a hostname' do
      it 'serializes the service check correctly' do
        expect(subject.format('windmill', 'grinding', hostname: 'amsterdam'))
          .to eq '_sc|windmill|grinding|h:amsterdam'
      end
    end

    context 'when having a message' do
      it 'serializes the service check correctly' do
        expect(subject.format('windmill', 'grinding', message: 'hum: something is fish|y'))
          .to eq '_sc|windmill|grinding|m:hum\: something is fishy'
      end
    end

    context 'when having a timestamp' do
      it 'serializes the service check correctly' do
        expect(subject.format('windmill', 'grinding', timestamp: Time.new(2020, 2, 22, 12, 22, 22, 0)))
          .to eq '_sc|windmill|grinding|d:2020-02-22 12:22:22 +0000'
      end
    end

    context 'when having tags' do
      let(:message_tags) do
        double('message tags')
      end

      before do
        allow(tag_serializer)
          .to receive(:format)
          .with(message_tags)
          .and_return('globaltag1:value1,msgtag2:value2')
      end

      it 'uses the tags serializer correctly' do
        expect(tag_serializer)
          .to receive(:format)
          .with(message_tags)

        subject.format('windmill', 'grinding', tags: message_tags)
      end

      it 'adds the tags to the service check correctly' do
        expect(subject.format('windmill', 'grinding', tags: message_tags))
          .to eq '_sc|windmill|grinding|#globaltag1:value1,msgtag2:value2'
      end
    end

    context 'when having several parameters (hostname, message, timestamp, tags)' do
      let(:message_tags) do
        double('message tags')
      end

      before do
        allow(tag_serializer)
          .to receive(:format)
          .with(message_tags)
          .and_return('globaltag1:value1,msgtag2:value2')
      end

      it 'serializes the service check correctly' do
        expect(subject.format('windmill', 'grinding',
          hostname: 'amsterdam',
          message: 'the wind is rising',
          tags: message_tags,
          timestamp: Time.new(2020, 2, 22, 12, 22, 22, 0))
        ).to eq '_sc|windmill|grinding|d:2020-02-22 12:22:22 +0000|h:amsterdam|m:the wind is rising|#globaltag1:value1,msgtag2:value2'
      end
    end
  end
end
