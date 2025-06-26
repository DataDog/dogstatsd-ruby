# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class StatSerializer
        def initialize(prefix, container_id, external_data, global_tags: [])
          @prefix = prefix
          @prefix_str = prefix.to_s
          @container_id = container_id
          @external_data = external_data
          @tag_serializer = TagSerializer.new(global_tags)
        end

        def format_fields
          field = String.new
          unless @container_id.nil?
            field << "|c:#{@container_id}"
          end

          unless @external_data.nil?
            field << "|e:#{@external_data}"
          end

          field
        end

        def format(metric_name, delta, type, tags: [], sample_rate: 1)
          metric_name = formatted_metric_name(metric_name)
          fields = format_fields

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
