# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class StatSerializer
        def initialize(prefix, global_tags: [])
          @prefix = prefix
          @tag_serializer = TagSerializer.new(global_tags)
        end

        def format(name, delta, type, tags: [], sample_rate: 1)
          String.new.tap do |stat|
            stat << prefix if prefix

            # stat value
            stat << formated_name(name)
            stat << ':'
            stat << delta.to_s

            # stat type
            stat << '|'
            stat << type

            # sample_rate
            if sample_rate != 1
              stat << '|'
              stat << '@'
              stat << sample_rate.to_s
            end

            # tags
            if tags_list = tag_serializer.format(tags)
              stat << '|'
              stat << '#'
              stat << tags_list
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
          formated = name.is_a?(String) ? name.dup : name.to_s

          formated.tap do |formated|
            # replace Ruby module scoping with '.'
            formated.gsub!('::', '.')
            # replace reserved chars (: | @) with underscores.
            formated.tr!(':|@', '_')
          end
        end
      end
    end
  end
end
