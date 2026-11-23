# frozen_string_literal: true

require_relative "mcp_copy/action_descriptions"
require_relative "mcp_copy/outputs"
require_relative "mcp_copy/type_descriptions"
require_relative "api/my_messages"

module RecordingStudioMessages
  # Registers named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  module McpCopy
    MY_MESSAGE_NAMES = Api::MyMessages::NAMES
    MY_MESSAGES_GROUP = Api::MyMessages::GROUP
    PRESS_CENTER_MESSAGES_GROUP = Api::Presets::PRESS_CENTER_MESSAGES

    module_function

    def register!
      return unless defined?(::RecordingStudioMcp)
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      Api::MyMessages.place!
      register_types
      register_press_center_tools
      register_my_message_tools
    end

    def tool_names(api: nil)
      press_center_tool_names(api: api) + my_message_tool_names(api: api)
    end

    def press_center_tool_names(api: nil)
      press_center_endpoints(api: api).map { |entry| entry.fetch(:name) }
    end

    def my_message_tool_names(api: nil)
      my_message_endpoints(api: api).map { |entry| entry.fetch(:name) }
    end

    def description_for(kind, action)
      ActionDescriptions.copy_for(kind, action).fetch(:description)
    end

    def register_types
      return unless ::RecordingStudioMcp.respond_to?(:register_type)

      TypeDescriptions::BY_TYPE.each do |type, description|
        ::RecordingStudioMcp.register_type(type: type, description: description)
      end
    end

    def register_press_center_tools
      press_center_endpoints.each { |entry| register_endpoint_tool(entry, :press_center) }
    end

    def register_my_message_tools
      my_message_endpoints.each { |entry| register_endpoint_tool(entry, :my_messages) }
    end

    def register_endpoint_tool(entry, kind)
      action = entry.fetch(:action)
      copy = ActionDescriptions.copy_for(kind, action)
      ::RecordingStudioMcp.register_tool(**tool_kwargs(entry, copy, action))
    end

    def tool_kwargs(entry, copy, action)
      endpoint = entry.fetch(:endpoint)
      {
        name: entry.fetch(:name),
        type: endpoint.recordable_type.presence || MESSAGE_GROUP_TYPE,
        endpoint: endpoint.name.to_sym,
        title: copy.fetch(:title),
        description: copy.fetch(:description),
        input: {},
        output: Outputs.for(kind_for(entry), action)
      }
    end

    def kind_for(entry)
      entry.fetch(:placement).actor_inbox? ? :my_messages : :press_center
    end

    def press_center_endpoints(api: nil)
      placed_endpoints(api: api).select { |entry| press_center_tool?(entry.fetch(:placement)) }
    end

    def my_message_endpoints(api: nil)
      placed_endpoints(api: api).select { |entry| entry.fetch(:placement).actor_inbox? }
    end

    def press_center_tool?(placement)
      placement.preset == Api::Presets::PRESS_CENTER
    end

    def placed_endpoints(api: nil)
      named_apis(api).flat_map do |name|
        registry = RecordingStudioApi.configuration.fetch_api(name).registered_endpoint_registry
        registry.all.filter_map { |endpoint| placed_entry(name, endpoint) }
      end
    end

    def placed_entry(api, endpoint)
      handler = endpoint.handler
      return unless messages_handler?(handler)
      return if handler.placement.preset == Api::Presets::SUPPORT

      { api:, name: endpoint.name.to_s, endpoint:, placement: handler.placement, action: handler.action }
    end

    def messages_handler?(handler)
      handler.respond_to?(:placement) && handler.respond_to?(:action)
    end

    def named_apis(api)
      return Array(api).map(&:to_sym) if api

      %i[public operations].select { |name| Api::MyMessages.named_api?(name) }
    end
  end
end
