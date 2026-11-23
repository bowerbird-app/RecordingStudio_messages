# frozen_string_literal: true

require_relative "mcp_copy/action_descriptions"
require_relative "mcp_copy/outputs"
require_relative "mcp_copy/type_descriptions"

module RecordingStudioMessages
  # Registers named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  module McpCopy
    module_function

    def mcp
      return unless defined?(::RecordingStudioMcp)

      ::RecordingStudioMcp
    end

    def mcp_available?
      mcp.respond_to?(:register_tool)
    end

    def register!
      return unless mcp_available?

      register_types
      register_press_center_tools
    end

    def tool_names(api: nil)
      placed_endpoints(api: api).map { |entry| entry.fetch(:name) }
    end

    def register_types
      client = mcp
      return unless client.respond_to?(:register_type)

      TypeDescriptions::BY_TYPE.each do |type, description|
        client.register_type(type: type, description: description)
      end
    end

    def register_press_center_tools
      client = mcp
      placed_endpoints.each { |entry| register_endpoint_tool(client, entry) }
    end

    def register_endpoint_tool(client, entry)
      action = entry.fetch(:action)
      names = sibling_names(entry.fetch(:placement))
      copy = ActionDescriptions.copy_for(action, names)
      client.register_tool(**tool_kwargs(entry, copy, action))
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
        output: Outputs.for(action)
      }
    end

    def sibling_names(placement)
      placement.endpoints.to_h { |endpoint| [endpoint.handler.action, endpoint.name.to_s] }
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
      return unless handler.placement.preset == Api::Presets::PRESS_CENTER

      { api:, name: endpoint.name.to_s, endpoint:, placement: handler.placement, action: handler.action }
    end

    def messages_handler?(handler)
      handler.respond_to?(:placement) && handler.respond_to?(:action)
    end

    def named_apis(api)
      names = RecordingStudioApi.configuration.api_names.map(&:to_s)
      return names if api.nil?

      key = api.to_s
      names.select { |name| name == key }
    end
  end
end
