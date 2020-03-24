# frozen_string_literal: true

module Datadog
  class Statsd
    module Serialization
      class EventSerializer
        EVENT_BASIC_OPTIONS = {
          date_happened:    'd:',
          hostname:         'h:',
          aggregation_key:  'k:',
          priority:         'p:',
          source_type_name: 's:',
          alert_type:       't:',
        }.freeze

        def initialize(global_tags: [])
          @tag_serializer = TagSerializer.new(global_tags)
        end

        def format(title, text, options = EMPTY_OPTIONS)
          title = clean(title)
          text = clean(text)

          String.new.tap do |event|
            event << '_e{'
            event << title.bytesize.to_s
            event << ','
            event << text.bytesize.to_s
            event << '}:'
            event << title
            event << '|'
            event << text

            # we are serializing the generic service check options
            # before serializing specialized options that need edge-cases
            EVENT_BASIC_OPTIONS.each do |option_key, shortcut|
              if value = options[option_key]
                event << '|'
                event << shortcut
                event << value.to_s.delete('|')
              end
            end

            if raw_tags = options[:tags]
              if tags = tag_serializer.format(raw_tags)
                event << '|#'
                event << tags
              end
            end

            if event.bytesize > MAX_EVENT_SIZE
              raise "Event #{title} payload is too big (more that 8KB), event discarded"
            end
          end
        end

        protected
        attr_reader :tag_serializer

        def clean(text)
          text.delete('|').tap do |text|
            text.gsub!("\n", '\n')
          end
        end
      end
    end
  end
end
