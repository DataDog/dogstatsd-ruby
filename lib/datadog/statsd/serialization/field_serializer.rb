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
          if @container_id.nil? && @external_data.nil? && cardinality.nil?
            # Avoid the allocation unless needed.
            return nil
          end

          field = String.new
          field << "|c:#{@container_id}" unless @container_id.nil?
          field << "|e:#{@external_data}" unless @external_data.nil?

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
