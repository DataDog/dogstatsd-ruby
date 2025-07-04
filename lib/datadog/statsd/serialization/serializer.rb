# frozen_string_literal: true

# require 'forwardable'

module Datadog
  class Statsd
    module Serialization
      class Serializer
        def initialize(prefix: nil, container_id: nil, external_data: nil, global_tags: [])
          @stat_serializer = StatSerializer.new(prefix, container_id, external_data, global_tags: global_tags)
          @service_check_serializer = ServiceCheckSerializer.new(container_id, external_data, global_tags: global_tags)
          @event_serializer = EventSerializer.new(container_id, external_data, global_tags: global_tags)
        end

        # using *args would make new allocations
        def to_stat(name, delta, type, tags: [], sample_rate: 1, cardinality: nil)
          stat_serializer.format(name, delta, type, tags: tags, sample_rate: sample_rate, cardinality: cardinality)
        end

        # using *args would make new allocations
        def to_service_check(name, status, options = EMPTY_OPTIONS)
          service_check_serializer.format(name, status, options)
        end

        # using *args would make new allocations
        def to_event(title, text, options = EMPTY_OPTIONS)
          event_serializer.format(title, text, options)
        end

        def global_tags
          stat_serializer.global_tags
        end

        protected
        attr_reader :stat_serializer
        attr_reader :service_check_serializer
        attr_reader :event_serializer
      end
    end
  end
end
