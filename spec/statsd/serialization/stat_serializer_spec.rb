require 'spec_helper'

describe Datadog::Statsd::Serialization::StatSerializer do
  subject do
    described_class.new(prefix, container_id, external_data, global_tags: global_tags)
  end

  let(:external_data) do
    nil
  end

  let(:container_id) do
    nil
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

    context 'when having a container id' do
      let(:container_id) do
        'in-23'
      end

      it 'adds the container id field correctly' do
        expect(subject.format('somecount', 42, 'c')).to eq 'somecount:42|c|c:in-23'
      end
    end

    context 'when having a prefix, tags, sample_rate and container id' do
      let(:prefix) do
        'swag.'
      end

      let(:message_tags) do
        double('message tags')
      end

      let(:container_id) do
        'in-23'
      end

      before do
        allow(tag_serializer)
          .to receive(:format)
          .with(message_tags)
          .and_return('globaltag1:value1,msgtag2:value2')
      end

      it 'adds the tags to the stat correctly' do
        expect(subject.format('somecount', 42, 'c', tags: message_tags, sample_rate: 0.5)).to eq 'swag.somecount:42|c|@0.5|c:in-23|#globaltag1:value1,msgtag2:value2'
      end
    end

    context 'when having external data' do
      let(:external_data) do
        'cn-SomeKindOfContainerName'
      end

      it 'adds the external data field correctly' do
        expect(subject.format('somecount', 42, 'c')).to eq 'somecount:42|c|e:cn-SomeKindOfContainerName'
      end
    end

    context "metric name contains unsupported characters" do
      it 'does not alter the provided metric name when containing ::' do
        input = 'somecount::test'
        output = subject.format(input, 1, 'c')
        expect(output).to eq 'somecount.test:1|c'
        expect(input).to eq 'somecount::test'
      end

      it 'does not alter the provided metric name when containing :|@' do
        input = 'somecount:|@test'
        output = subject.format(input, 1, 'c')
        expect(output).to eq 'somecount___test:1|c'
        expect(input).to eq 'somecount:|@test'
      end
    end

    context 'when having cardinality' do
      it 'adds the cardinality field correctly' do
        expect(subject.format('somecount', 42, 'c', cardinality: :high)).to eq 'somecount:42|c|card:high'
        expect(subject.format('somecount', 42, 'c', cardinality: 'none')).to eq 'somecount:42|c|card:none'
      end

      it 'validates the cardinality is correct' do
        expect {
          subject.format('somecount', 42, 'c', cardinality: :potato)
        }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq 'Invalid cardinality potato. Valid options are none, low, orchestrator, high.'
        end
      end
    end

    context "when metric name is a symbol" do
      it 'formats correctly without error' do
        input = :'somecount::test'
        output = subject.format(input, 1, 'c')
        expect(output).to eq 'somecount.test:1|c'

        input = :'somecount:|@test'
        output = subject.format(input, 1, 'c')
        expect(output).to eq 'somecount___test:1|c'
      end
    end
  end

  context 'benchmark' do
    before { skip("Benchmarks results are currently not used by CI") if ENV.key?('CI') }

    def benchmark_setup(x)
      s = subject # Avoid RSpec lookup on every iteration
      name = 'somecount'
      type = 'c'
      tags = ["host:storage", "network:gigabit", "request:xyz"]

      x.report("no tags") { s.format(name, 42, type) }
      x.report("no tags + sample rate") { s.format(name, 42, type, sample_rate: 0.5) }
      x.report("with tags") { s.format(name, 42, type, tags: tags) }
      x.report("with tags + sample rate") { s.format(name, 42, type, tags: tags, sample_rate: 0.5) }
    end

    it 'measure IPS' do
      require 'benchmark/ips'

      Benchmark.ips do |x|
        benchmark_setup(x)

        x.compare!
      end
    end

    it 'measure memory' do
      require 'benchmark-memory'

      Benchmark.memory do |x|
        benchmark_setup(x)

        x.compare!
      end
    end
  end
end
