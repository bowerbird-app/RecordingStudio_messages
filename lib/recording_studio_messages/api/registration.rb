# frozen_string_literal: true

require_relative "actions"
require_relative "group_catalog"
require_relative "mount_catalog"

module RecordingStudioMessages
  module Api
    module Registration
      module_function

      def register!(api)
        register_type(api, MESSAGE_GROUP_TYPE, %i[title], [], :serialize_group)
        register_type(api, MESSAGE_MOUNT_TYPE, %i[key], [], :serialize_mount)
        GroupCatalog::ACTIONS.each { |name, spec| register_endpoint(api, name, spec) }
        MountCatalog::ENDPOINTS.each { |name, spec| register_endpoint(api, name, spec) }
      end

      def register_type(api, type, output_keys, actions, serializer)
        if ::RecordingStudioApi.recordable_registration_for(type, api:)
          raise ::RecordingStudioApi::ConfigurationError, "API type #{type} is already registered"
        end

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

      def register_endpoint(api, name, spec)
        if ::RecordingStudioApi.registered_endpoint(name, api:)
          raise ::RecordingStudioApi::ConfigurationError, "API endpoint #{name} is already registered"
        end

        ::RecordingStudioApi.register_endpoint(name, **endpoint_kwargs(api, spec))
      end

      def endpoint_kwargs(api, spec)
        {
          api:,
          http_verb: spec[:http_verb],
          path: spec[:path],
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
