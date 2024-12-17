require 'spec_helper'

describe Datadog::Statsd::Serialization::TagSerializer do
  subject do
    described_class.new(global_tags)
  end

  let(:global_tags) do
    []
  end

  describe '#format' do
    context '[testing parameter types]' do
      [nil, [], {}].each do |empty_value_gt|
        context "when there is no global tags (#{empty_value_gt.inspect})" do
          let(:global_tags) do
            empty_value_gt
          end

          [nil, [], {}].each do |empty_value_mt|
            context "when there is no message tags (#{empty_value_mt.inspect})" do
              it 'returns nil' do
                expect(subject.format(empty_value_mt)).to be nil
              end
            end
          end

          context 'when the message tags is an array' do
            let(:message_tags) do
              %w(request:xyz another:mal|for,med)
            end

            it 'returns global tags and message tags' do
              expect(subject.format(message_tags)).to eq 'request:xyz,another:malformed'
            end
          end

          context 'when the message tags is a hash' do
            let(:message_tags) do
              {
                request: :xyz,
                'another' => 'mal|for,med',
              }
            end

            it 'returns global tags and message tags' do
              expect(subject.format(message_tags)).to eq 'request:xyz,another:malformed'
            end
          end
        end
      end

      context 'when the global tags is an array' do
        let(:global_tags) do
          %w[host:storage network:gigabit yolo:malformed|ta,g]
        end

        [nil, [], {}].each do |empty_value_mt|
          context "when there is no message tags (#{empty_value_mt.inspect})" do
            it 'returns only global tags' do
              expect(subject.format(empty_value_mt)).to eq 'host:storage,network:gigabit,yolo:malformedtag'
            end
          end
        end

        context 'when the message tags is an array' do
          let(:message_tags) do
            %w(request:xyz another:mal|for,med)
          end

          it 'returns global tags and message tags' do
            expect(subject.format(message_tags)).to eq 'host:storage,network:gigabit,yolo:malformedtag,request:xyz,another:malformed'
          end
        end

        context 'when the message tags is a hash' do
          let(:message_tags) do
            {
              request: :xyz,
              'another' => 'mal|for,med',
            }
          end

          it 'returns global tags and message tags' do
            expect(subject.format(message_tags)).to eq 'host:storage,network:gigabit,yolo:malformedtag,request:xyz,another:malformed'
          end
        end
      end

      context 'when the global tags is a hash' do
        let(:global_tags) do
          {
            host: 'storage',
            'network' => :gigabit,
            yolo: 'malformed|ta,g',
          }
        end

        [nil, [], {}].each do |empty_value_mt|
          context "when there is no message tags (#{empty_value_mt.inspect})" do
            it 'returns only global tags' do
              expect(subject.format(empty_value_mt)).to eq 'host:storage,network:gigabit,yolo:malformedtag'
            end
          end
        end

        context 'when the message tags is an array' do
          let(:message_tags) do
            %w(request:xyz another:mal|for,med)
          end

          it 'returns global tags and message tags' do
            expect(subject.format(message_tags)).to eq 'host:storage,network:gigabit,yolo:malformedtag,request:xyz,another:malformed'
          end
        end

        context 'when the message tags is a hash' do
          let(:message_tags) do
            {
              request: :xyz,
              'another' => 'mal|for,med',
            }
          end

          it 'returns global tags and message tags' do
            expect(subject.format(message_tags)).to eq 'host:storage,network:gigabit,yolo:malformedtag,request:xyz,another:malformed'
          end
        end
      end
    end

    context '[testing serialization edge cases]' do
      it 'formats tags with reserved characters' do
        expect(subject.format(['name:foo,bar|foo'])).to eq 'name:foobarfoo'
        expect(subject.format(['name:foobar|foo'])).to eq 'name:foobarfoo'
        expect(subject.format(['name:foo, bar, and foo'])).to eq 'name:foo bar and foo'
      end

      it 'formats tags values with to_s' do
        tag = double('some tag', to_s: 'node:storage')
        expect(subject.format([tag])).to eq 'node:storage'
      end

      it 'formats frozen tags correctly' do
        expect(subject.format(['name:foobarfoo'.freeze])).to eq 'name:foobarfoo'
      end

      it 'does not alter the provided tag value when containing unsupported characters' do
        input = 'name|foobar'
        output = subject.format([input])
        expect(output).to eq 'namefoobar'
        expect(input).to eq 'name|foobar'
      end
    end

    context '[testing management of env vars]' do
      context 'when testing DD_TAGS' do
        around do |example|
          ClimateControl.modify(
            'DD_TAGS' => 'ghi,team:qa'
          ) do
            example.run
          end
        end

        it 'correctly adds individual tags' do
          expect(subject.format([])).to eq 'ghi,team:qa'
        end
      end

      context 'when testing DD_ENTITY_ID' do
        around do |example|
          ClimateControl.modify(
            'DD_ENTITY_ID' => '04652bb7-19b7-11e9-9cc6-42010a9c016d'
          ) do
            example.run
          end
        end

        it 'correctly adds the entity_id tag' do
          expect(subject.format([])).to eq 'dd.internal.entity_id:04652bb7-19b7-11e9-9cc6-42010a9c016d'
        end
      end

      context 'when testing DD_ENV' do
        around do |example|
          ClimateControl.modify(
            'DD_ENV' => 'staging'
          ) do
            example.run
          end
        end

        it 'correctly adds the env tag' do
          expect(subject.format([])).to eq 'env:staging'
        end
      end

      context 'when testing DD_SERVICE' do
        around do |example|
          ClimateControl.modify(
            'DD_SERVICE' => 'billing-service'
          ) do
            example.run
          end
        end

        it 'correctly adds the service tag' do
          expect(subject.format([])).to eq 'service:billing-service'
        end
      end

      context 'when testing DD_VERSION' do
        around do |example|
          ClimateControl.modify(
            'DD_VERSION' => '0.1.0-alpha'
          ) do
            example.run
          end
        end

        it 'correctly adds the version tag' do
          expect(subject.format([])).to eq 'version:0.1.0-alpha'
        end
      end
    end

    context 'benchmark' do
      before { skip("Benchmarks results are currently not used by CI") if ENV.key?('CI') }

      def benchmark_setup(x)
        global_tags = %w(app:foo env:abc version:123)
        tags_array = %w(host:storage network:gigabit request:xyz)
        tags_hash = { host: "storage", network: "gigabit", request: "xyz" }
        tags_empty = []

        subject_without_global_tags = described_class.new
        subject_with_global_tags = described_class.new(global_tags)

        x.report("no tags") { subject_without_global_tags.format(tags_empty) }
        x.report("global tags") { subject_with_global_tags.format(tags_empty) }
        x.report("tags Array") { subject_without_global_tags.format(tags_array) }
        x.report("tags Hash") { subject_without_global_tags.format(tags_hash) }
        x.report("tags Array + global tags") { subject_with_global_tags.format(tags_array) }
        x.report("tags Hash + global tags") { subject_with_global_tags.format(tags_hash) }
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
end
