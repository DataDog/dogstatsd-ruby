# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class StatSerializer
        def initialize(prefix, container_id, external_data, global_tags: [])
          @prefix = prefix
          @prefix_str = prefix.to_s
          @tag_serializer = TagSerializer.new(global_tags)
          @field_serializer = FieldSerializer.new(container_id, external_data)
        end

        def format(metric_name, delta, type, tags: [], sample_rate: 1, cardinality: nil)
          metric_name = formatted_metric_name(metric_name)
          fields = field_serializer.format(cardinality)

          if sample_rate != 1
            if tags_list = tag_serializer.format(tags)
              "#{@prefix_str}#{metric_name}:#{delta}|#{type}|@#{sample_rate}#{fields}|##{tags_list}"
            else
              "#{@prefix_str}#{metric_name}:#{delta}|#{type}|@#{sample_rate}#{fields}"
            end
          else
            if tags_list = tag_serializer.format(tags)
              "#{@prefix_str}#{metric_name}:#{delta}|#{type}|##{tags_list}#{fields}"
            else
              "#{@prefix_str}#{metric_name}:#{delta}|#{type}#{fields}"
            end
          end
        end

        def global_tags
          tag_serializer.global_tags
        end

        private

        attr_reader :prefix
        attr_reader :tag_serializer
        attr_reader :field_serializer

        if RUBY_VERSION < '3'
          def metric_name_to_string(metric_name)
            metric_name.to_s
          end
        else
          def metric_name_to_string(metric_name)
            Symbol === metric_name ? metric_name.name : metric_name.to_s
          end
        end

        def formatted_metric_name(metric_name)
          formatted = metric_name_to_string(metric_name)
          if formatted.include?('::')
            formatted = formatted.gsub('::', '.')
            formatted.tr!(':|@', '_')
            formatted
          elsif formatted.include?(':') || formatted.include?('@') || formatted.include?('|')
            formatted.tr(':|@', '_')
          else
            formatted
          end
        end
      end
    end
  end
end
