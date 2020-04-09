# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class TagSerializer
        def initialize(global_tags = [], env = ENV)
          # Convert to hash
          global_tags = to_tags_hash(global_tags)

          # Merge with default tags
          global_tags = default_tags(env).merge(global_tags)

          # Convert to tag list and set
          @global_tags = to_tags_list(global_tags)
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

        def to_tags_hash(tags)
          case tags
          when Hash
            tags.dup
          when Array
            Hash[
              tags.collect do |string|
                string.split(':').tap do |tokens|
                  tokens << nil if tokens.length == 1
                end
              end
            ]
          else
            {}
          end
        end

        def to_tags_list(tags)
          case tags
          when Hash
            tags.each_with_object([]) do |tag_pair, formatted_tags|
              if tag_pair.last.nil?
                formatted_tags << "#{tag_pair.first}"
              else
                formatted_tags << "#{tag_pair.first}:#{tag_pair.last}"
              end
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

        def dd_tags(env = ENV)
          return {} unless dd_tags = env['DD_TAGS']

          to_tags_hash(dd_tags.split(','))
        end

        def default_tags(env = ENV)
          dd_tags(env).tap do |tags|
            tags['dd.internal.entity_id'] = env['DD_ENTITY_ID'] if env.key?('DD_ENTITY_ID')
            tags['env'] = env['DD_ENV'] if env.key?('DD_ENV')
            tags['service'] = env['DD_SERVICE'] if env.key?('DD_SERVICE')
            tags['version'] = env['DD_VERSION'] if env.key?('DD_VERSION')
          end
        end
      end
    end
  end
end
