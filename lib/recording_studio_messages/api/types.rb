# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Types
      SHOW_ONLY = %i[show].freeze

      module_function

      def register!(api)
        type_specs.each { |type, spec| register_type!(api, type, spec) }
      end

      def type_specs
        {
          RecordingStudioMessages::MESSAGE_TYPE => spec(:body),
          RecordingStudioMessages::MESSAGE_GROUP_TYPE => spec(:title),
          RecordingStudioMessages::MESSAGE_MOUNT_TYPE => spec(:key)
        }
      end

      def spec(key)
        {
          output_keys: [key],
          serializer: ->(recordable, **) { { key => recordable.public_send(key) } }
        }
      end

      def register_type!(api, type, spec)
        existing = ::RecordingStudioApi.recordable_registration_for(type, api: api)
        return if show_only?(existing)
        raise already_registered(type) if existing

        write_type!(api, type, spec)
      end

      def write_type!(api, type, spec)
        ::RecordingStudioApi.register_recordable_type_api(
          type,
          api: api,
          operations: SHOW_ONLY,
          auto_capability_actions: false,
          capability_actions: [],
          output_keys: spec.fetch(:output_keys),
          serializer: spec.fetch(:serializer),
          public_name: type.to_s.split("::").last
        )
      end

      def already_registered(type)
        ::RecordingStudioApi::ConfigurationError.new(
          "API type #{type} is already registered, and it is not show-only"
        )
      end

      def show_only?(registration)
        registration&.operations == SHOW_ONLY
      end
    end
  end
end
