# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class StatSerializer
        def initialize(prefix, global_tags: [])
          @prefix = prefix
          @prefix_str = prefix.to_s
          @tag_serializer = TagSerializer.new(global_tags)
        end

        def format(name, delta, type, tags: [], sample_rate: 1)
          name = formated_name(name)

          if sample_rate != 1
            if tags_list = tag_serializer.format(tags)
              "#{@prefix_str}#{name}:#{delta}|#{type}|@#{sample_rate}|##{tags_list}"
            else
              "#{@prefix_str}#{name}:#{delta}|#{type}|@#{sample_rate}"
            end
          else
            if tags_list = tag_serializer.format(tags)
              "#{@prefix_str}#{name}:#{delta}|#{type}|##{tags_list}"
            else
              "#{@prefix_str}#{name}:#{delta}|#{type}"
            end
          end
        end

        def global_tags
          tag_serializer.global_tags
        end

        private

        attr_reader :prefix
        attr_reader :tag_serializer

        def formated_name(name)
          formated = name.is_a?(String) ? name : name.to_s

          if formated.include?('::')
            formated = formated.gsub('::', '.')
            formated.tr!(':|@', '_')
            formated
          elsif formated.include?(':') || formated.include?('@') || formated.include?('|')
            formated.tr(':|@', '_')
          else
            formated
          end
        end
      end
    end
  end
end
