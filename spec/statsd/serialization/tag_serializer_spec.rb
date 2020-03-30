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
      end

      it 'formats tags values with to_s' do
        tag = double('some tag', to_s: 'node:storage')
        expect(subject.format([tag])).to eq 'node:storage'
      end

      it 'formats frozen tags correctly' do
        expect(subject.format(['name:foobarfoo'.freeze])).to eq 'name:foobarfoo'
      end
    end
  end
end
