# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class FieldSerializer
        VALID_CARDINALITY = [:none, :low, :orchestrator, :high]

        def initialize(container_id, external_data)
          @container_id = container_id
          @external_data = external_data
        end

        def format(cardinality)
          field = String.new
          unless @container_id.nil?
            field << "|c:#{@container_id}"
          end

          unless @external_data.nil?
            field << "|e:#{@external_data}"
          end

          unless cardinality.nil?
            unless VALID_CARDINALITY.include?(cardinality.to_sym)
              raise ArgumentError, "Invalid cardinality #{cardinality}. Valid options are #{VALID_CARDINALITY.join(', ')}."
            end

            field << "|card:#{cardinality}"
          end

          field
        end
      end
    end
  end
end
