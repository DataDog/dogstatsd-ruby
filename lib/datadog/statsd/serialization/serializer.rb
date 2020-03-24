# frozen_string_literal: true

# require 'forwardable'

module Datadog
  class Statsd
    module Serialization
      class Serializer
        def initialize(prefix: nil, global_tags: [])
          @stat_serializer = StatSerializer.new(prefix, global_tags: global_tags)
        end

        # using *args would make new allocations
        def to_stat(name, delta, type, tags: [], sample_rate: 1)
          stat_serializer.format(name, delta, type, tags: tags, sample_rate: sample_rate)
        end

        protected
        attr_reader :stat_serializer
      end
    end
  end
end
