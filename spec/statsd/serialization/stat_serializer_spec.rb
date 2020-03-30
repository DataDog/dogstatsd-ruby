require 'spec_helper'

describe Datadog::Statsd::Serialization::StatSerializer do
  subject do
    described_class.new(prefix, global_tags: global_tags)
  end

  let(:prefix) do
    nil
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

    it 'serializes the stat correctly' do
      expect(subject.format('somecount', -2, 'c')).to eq 'somecount:-2|c'
    end

    context 'when there is a prefix' do
      let(:prefix) do
        'swag.'
      end

      it 'prefixes the stat correctly' do
        expect(subject.format('somecount', -2, 'c')).to eq 'swag.somecount:-2|c'
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

        subject.format('somecount', 42, 'c', tags: message_tags)
      end

      it 'adds the tags to the stat correctly' do
        expect(subject.format('somecount', 42, 'c', tags: message_tags)).to eq 'somecount:42|c|#globaltag1:value1,msgtag2:value2'
      end
    end

    context 'when having a sample rate' do
      it 'serializes the stat correctly' do
        expect(subject.format('somecount', -2, 'c', sample_rate: 0.5)).to eq 'somecount:-2|c|@0.5'
      end
    end

    context 'when having a prefix, tags and a sample_rate' do
      let(:prefix) do
        'swag.'
      end

      let(:message_tags) do
        double('message tags')
      end

      before do
        allow(tag_serializer)
          .to receive(:format)
          .with(message_tags)
          .and_return('globaltag1:value1,msgtag2:value2')
      end

      it 'adds the tags to the stat correctly' do
        expect(subject.format('somecount', 42, 'c', tags: message_tags, sample_rate: 0.5)).to eq 'swag.somecount:42|c|@0.5|#globaltag1:value1,msgtag2:value2'
      end
    end
  end
end
