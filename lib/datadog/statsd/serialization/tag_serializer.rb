# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class TagSerializer
        def initialize(global_tags = [], env = ENV)
          @global_tags = to_tags_list(global_tags)

          # append the entity id to tags if DD_ENTITY_ID env var is set
          if dd_entity = env.fetch('DD_ENTITY_ID', nil)
            @global_tags << to_tags_list('dd.internal.entity_id' => dd_entity).first
          end
        end

        def format(message_tags)
          # fast return global tags if there's no message_tags
          # to avoid more allocations
          tag_list =  if message_tags && message_tags.any?
                        global_tags + to_tags_list(message_tags)
                      else
                        global_tags
                      end

          tag_list.join(',') if tag_list.any?
        end

        attr_reader :global_tags

        private
        def to_tags_list(tags)
          case tags
          when Hash
            tags.each_with_object([]) do |tag_pair, formated_tags|
              formated_tags << "#{tag_pair.first}:#{tag_pair.last}"
            end
          when Array
            tags.dup
          else
            []
          end.map! do |tag|
            escape_tag_content(tag)
          end
        end

        def escape_tag_content(tag)
          tag.to_s.delete('|,')
        end
      end
    end
  end
end
