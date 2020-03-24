# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
    end
  end
end

require_relative 'serialization/tag_serializer'
require_relative 'serialization/stat_serializer'
