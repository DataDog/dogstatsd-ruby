require 'spec_helper'

describe Datadog::Statsd::Serialization::EventSerializer do
  subject do
    described_class.new(container_id, external_data, global_tags: global_tags)
  end

  let(:external_data) do
    nil
  end

  let(:container_id) do
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

    it 'serializes the event correctly' do
      expect(subject.format('this is a title', 'this is a longer text'))
        .to eq '_e{15,21}:this is a title|this is a longer text'
    end

    it 'serializes events containing non-ascii characters correctly' do
      # the _e{..,..} syntax measures in bytes, not characters
      # 🎈 is f09f8e88 in utf-8
      # 🤡 is f09fa4a1 in utf-8
      expect(subject.format('🎈', '🤡'))
        .to eq '_e{4,4}:🎈|🤡'
    end

    context 'when there are global tags' do
      before do
        allow(tag_serializer)
          .to receive(:format)
          .with(nil)
          .and_return('a-global-tag,another-global')
      end

      it 'serializes the event correctly with global tags' do
        expect(subject.format('this is a title', 'this is a longer text'))
          .to eq '_e{15,21}:this is a title|this is a longer text|#a-global-tag,another-global'
      end
    end

    context 'when the event description is too long (> 8KB)' do
      it 'raises a specific error' do
        expect do
          subject.format('this is a title', 'this is a longer text' * 1000)
        end.to raise_error(RuntimeError, /payload is too big/)
      end

      context 'when the truncate_if_too_long option is true' do
        let(:options) { { truncate_if_too_long: true } }

        it 'truncates the overage' do
          expect(subject.format('this is a title', 'this is a longer text' * 1000, options).bytesize)
            .to eq Datadog::Statsd::MAX_EVENT_SIZE
        end
      end
    end

    context 'when having an alert type' do
      it 'serializes the event correctly with a known alert type' do
        expect(subject.format('this is a title', 'this is a longer text', alert_type: 'warning'))
          .to eq '_e{15,21}:this is a title|this is a longer text|t:warning'
      end

      it 'serializes the event correctly with an unknown alert type' do
        expect(subject.format('this is a title', 'this is a longer text', alert_type: 'yolo'))
          .to eq '_e{15,21}:this is a title|this is a longer text|t:yolo'
      end
    end

    context 'when having a priority' do
      it 'serializes the event correctly with a known alert type' do
        expect(subject.format('this is a title', 'this is a longer text', priority: 'low'))
          .to eq '_e{15,21}:this is a title|this is a longer text|p:low'
      end

      it 'serializes the event correctly with an unknown alert type' do
        expect(subject.format('this is a title', 'this is a longer text', priority: 'urgente'))
          .to eq '_e{15,21}:this is a title|this is a longer text|p:urgente'
      end
    end

    context 'when having a timestamp' do
      it 'serializes the event correctly' do
        expect(subject.format('this is a title', 'this is a longer text', date_happened: Time.new(2020, 2, 22, 12, 22, 22, 0)))
          .to eq '_e{15,21}:this is a title|this is a longer text|d:2020-02-22 12:22:22 +0000'
      end
    end

    context 'when having a hostname' do
      it 'serializes the event correctly' do
        expect(subject.format('this is a title', 'this is a longer text', hostname: 'amsterdam'))
          .to eq '_e{15,21}:this is a title|this is a longer text|h:amsterdam'
      end
    end

    context 'when having an aggregation key' do
      it 'serializes the event correctly' do
        expect(subject.format('this is a title', 'this is a longer text', aggregation_key: 'some key'))
          .to eq '_e{15,21}:this is a title|this is a longer text|k:some key'
      end
    end

    context 'when having a source type name' do
      it 'serializes the event correctly' do
        expect(subject.format('this is a title', 'this is a longer text', source_type_name: 'the source'))
          .to eq '_e{15,21}:this is a title|this is a longer text|s:the source'
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

      it 'adds the tags to the event correctly' do
        expect(subject.format('this is a title', 'this is a longer text', tags: message_tags))
          .to eq '_e{15,21}:this is a title|this is a longer text|#globaltag1:value1,msgtag2:value2'
      end
    end

    context 'when having a container id' do
      let(:container_id) do
        'in-23'
      end

      it 'adds the container id field correctly' do
        expect(subject.format('this is a title', 'this is a longer text'))
          .to eq '_e{15,21}:this is a title|this is a longer text|c:in-23'
      end

      it 'adds the cardinality field correctly' do
        expect(subject.format('this is a title', 'this is a longer text', cardinality: :low))
          .to eq '_e{15,21}:this is a title|this is a longer text|c:in-23|card:low'
      end
    end

    context 'when having several parameters (hostname, alert_type, priority, source_type, timestamp, tags)' do
      let(:message_tags) do
        double('message tags')
      end

      before do
        allow(tag_serializer)
          .to receive(:format)
          .with(message_tags)
          .and_return('globaltag1:value1,msgtag2:value2')
      end

      it 'serializes the event correctly' do
        expect(subject.format('this is a title', 'this is a longer text',
          hostname: 'amsterdam',
          alert_type: 'warning',
          priority: 'low',
          source_type_name: 'source',
          tags: message_tags,
          timestamp: Time.new(2020, 2, 22, 12, 22, 22, 0))
        ).to eq '_e{15,21}:this is a title|this is a longer text|h:amsterdam|p:low|s:source|t:warning|#globaltag1:value1,msgtag2:value2'
      end
    end

    context '[testing edge cases on title and text]' do
      it 'protects linebreaks on title' do
        expect(subject.format("this is\na title", 'this is a longer text')).to eq '_e{16,21}:this is\na title|this is a longer text'
      end

      it 'protects linebreaks on text' do
        expect(subject.format('this is a title', "this is a\nlonger text")).to eq '_e{15,22}:this is a title|this is a\nlonger text'
      end
    end
  end
end
