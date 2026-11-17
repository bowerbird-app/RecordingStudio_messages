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
        register_type(api, MESSAGE_TYPE, %i[body], [], :serialize_message)
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
        }.merge(scope_kwargs(spec))
      end

      def scope_kwargs(spec)
        kwargs = { required_role: spec.fetch(:required_role) }
        type = recordable_type_for(spec[:path])
        kwargs[:recordable_type] = type if type
        kwargs
      end

      def recordable_type_for(path)
        return MESSAGE_GROUP_TYPE if path.start_with?("conversations/:id")
        return MESSAGE_MOUNT_TYPE if path.start_with?("message_centers/:id")

        nil
      end

      def openapi(spec)
        document = {
          title: spec[:title],
          summary: spec[:summary],
          description: spec[:description]
        }
        parameters = path_parameters(spec)
        document[:parameters] = parameters if parameters
        document
      end

      def path_parameters(spec)
        description = spec[:id_description]
        return if description.blank?

        [{
          name: "id", in: "path", required: true,
          schema: { type: "string" }, description: description
        }]
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

      def serialize_message(message, **)
        { body: message.body }
      end
    end
  end
end
