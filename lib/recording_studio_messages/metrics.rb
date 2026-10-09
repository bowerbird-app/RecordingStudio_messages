# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioMessages
  module Metrics
    API = :operations
    EXPOSE = { api: [API] }.freeze

    module_function

    def register!
      register_messages
      register_message_groups
      register_contact_intents
    end

    def register_messages
      register_resource(
        :messages,
        model: RecordingStudio::Recording,
        scope: recordings_scope(MESSAGE_TYPE)
      ) do
        timeseries :sent_over_time, title: "Messages sent over time", field: :created_at, expose: EXPOSE
      end
    end

    def register_message_groups
      register_resource(
        :message_groups,
        model: RecordingStudio::Recording,
        scope: recordings_scope(MESSAGE_GROUP_TYPE)
      ) do
        timeseries :created_over_time, title: "Conversations created over time", field: :created_at, expose: EXPOSE
      end
    end

    def register_contact_intents
      register_resource(:contact_intents, model: PublicContactIntent) do
        timeseries :submitted_over_time,
                   title: "Contact intents submitted over time",
                   field: :created_at,
                   expose: EXPOSE
        RecordingStudioMessages::Metrics.define_converted(self)
      end
    end

    def define_converted(dsl)
      dsl.custom :converted,
                 result_type: :breakdown,
                 title: "Contact intent conversion",
                 expose: EXPOSE,
                 &converted_calculator
    end

    def converted_calculator
      lambda do |relation, _context|
        now = Time.current
        converted = relation.where.not(message_group_id: nil)
        leftover = relation.where(message_group_id: nil)
        [
          { key: "converted", value: converted.distinct.count },
          { key: "expired", value: leftover.where("expires_at <= ?", now).distinct.count },
          { key: "pending", value: leftover.where("expires_at > ?", now).distinct.count }
        ]
      end
    end

    def register_resource(name, model:, scope: nil, &)
      RecordingStudioMetrics.register(
        name,
        model: model,
        blast_radius: :site,
        scope: scope,
        api_authorize: access_check,
        &
      )
    end

    def recordings_scope(recordable_type)
      lambda do |relation|
        relation.where(recordable_type: recordable_type, trashed_at: nil)
      end
    end

    def access_check
      ->(context) { RecordingStudioMessages::Api::Access.can_view?(context) }
    end
  end
end
