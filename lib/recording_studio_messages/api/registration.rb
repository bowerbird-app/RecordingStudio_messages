# frozen_string_literal: true

require_relative "actions"
require_relative "group_catalog"
require_relative "mount_catalog"

module RecordingStudioMessages
  module Api
    module Registration
      module_function

      def register!(api)
        enable_messages_types!
        register_type(api, MESSAGE_GROUP_TYPE, %i[title], GroupCatalog::ACTIONS.keys, :serialize_group)
        register_type(api, MESSAGE_MOUNT_TYPE, %i[key], MountCatalog::ACTIONS.keys, :serialize_mount)
        GroupCatalog::ACTIONS.each { |name, spec| register_action(api, name, spec) }
        MountCatalog::ACTIONS.each { |name, spec| register_action(api, name, spec) }
        register_endpoint(api, :unread_count, MountCatalog::UNREAD_COUNT)
      end

      def enable_messages_types!
        RecordingStudio.enable_capability(:messages, on: RecordingStudioMessages::MessageGroup)
        RecordingStudio.enable_capability(:messages, on: RecordingStudioMessages::MessageMount)
      end

      def register_type(api, type, output_keys, actions, serializer)
        return if ::RecordingStudioApi.recordable_registration_for(type, api:)

        ::RecordingStudioApi.register_recordable_type_api(type, **type_kwargs(api, output_keys, actions, serializer))
      end

      def type_kwargs(api, output_keys, actions, serializer)
        {
          api:,
          operations: %i[show],
          auto_capability_actions: false,
          capability_actions: actions,
          serializer: method(serializer),
          output_keys:
        }
      end

      def register_action(api, name, spec)
        register_capability(api, name, spec)
        register_endpoint(api, name, spec)
      end

      def register_capability(api, name, spec)
        return if ::RecordingStudioApi.capability_action(name, api:)

        ::RecordingStudioApi.register_capability_action(name, **capability_kwargs(api, spec))
      end

      def register_endpoint(api, name, spec)
        return if ::RecordingStudioApi.registered_endpoint(name, api:)

        ::RecordingStudioApi.register_endpoint(name, **endpoint_kwargs(api, spec))
      end

      def capability_kwargs(api, spec)
        shared_kwargs(api, spec).merge(
          capability: :messages,
          version: "1.0.0",
          required_role: spec[:required_role]
        )
      end

      def endpoint_kwargs(api, spec)
        shared_kwargs(api, spec).merge(path: spec[:path])
      end

      def shared_kwargs(api, spec)
        {
          api:,
          http_verb: spec[:http_verb],
          handler: Actions.const_get(spec[:handler]),
          serializer: method(:passthrough),
          input_contract: { reject_unknown: false, fields: spec[:fields] },
          openapi: openapi(spec)
        }
      end

      def openapi(spec)
        {
          title: spec[:title],
          summary: spec[:summary],
          description: spec[:description]
        }
      end

      def passthrough(result)
        result
      end

      def serialize_group(group, **)
        { title: group.title }
      end

      def serialize_mount(mount, **)
        { key: mount.key }
      end
    end
  end
end
