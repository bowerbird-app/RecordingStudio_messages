# frozen_string_literal: true

require_relative "actions"
require_relative "catalog"
require_relative "mount_binding"
require_relative "presets"
require_relative "types"

module RecordingStudioMessages
  module Api
    module PlacementHelpers
      private

      def registry
        ::RecordingStudioApi.configuration.api(api).registered_endpoint_registry
      end

      def symbolize(values)
        values.to_h { |key, value| [key.to_sym, value] }
      end

      def configuration_error(message)
        ::RecordingStudioApi::ConfigurationError.new(message)
      end
    end

    class Placement
      include PlacementHelpers

      attr_reader :api, :at, :mount_binding, :actions, :endpoints, :names, :descriptions,
                  :titles, :tags, :tag_group, :preset

      def self.place(**)
        placement = new(**)
        placement.register!
        placement
      end

      def initialize(api:, at:, mount:, **copy)
        require_api!
        @api = api
        @at = normalize_at(at)
        @mount_binding = MountBinding.wrap(mount)
        prepare(copy)
      end

      def parent?
        mount_binding.parent?
      end

      def actor_inbox?
        mount_binding.actor_inbox?
      end

      def register!
        Types.register!(api)
        pending = endpoints.reject { |endpoint| identical?(endpoint) }
        pending.each { |endpoint| assert_available!(endpoint) }
        write_all(pending)
      end

      private

      def require_api!
        return if defined?(::RecordingStudioApi)

        raise RecordingStudioMessages::Error, "Recording Studio API is not loaded"
      end

      def prepare(copy)
        @preset = copy[:preset].nil? ? nil : Presets.fetch(copy[:preset])
        @actions = normalize_actions(copy[:actions])
        assign_copy(copy)
        @endpoints = @actions.map { |action| Draft.build(self, action) }
        assert_plan_unique!
      end

      def assign_copy(copy)
        @names = symbolize(copy.fetch(:names, {}))
        @descriptions = symbolize(copy.fetch(:descriptions, {}))
        @titles = symbolize(copy.fetch(:titles, {}))
        assign_tags(copy)
        assert_override_keys!
      end

      def assign_tags(copy)
        @tags = copy[:tags].nil? ? @preset&.tags || [Presets::MESSAGE_CENTER] : Array(copy[:tags])
        @tag_group = copy[:tag_group].nil? ? @preset&.tag_group : copy[:tag_group]
      end

      def normalize_at(at)
        Segment.normalize(at, api)
      end

      def normalize_actions(actions)
        chosen = actions.nil? ? default_actions : Array(actions).map(&:to_sym)
        unknown = chosen - Catalog::ACTIONS.keys
        raise configuration_error("Unknown messages API actions: #{unknown.join(', ')}") if unknown.any?
        raise configuration_error("Choose at least one messages API action") if chosen.empty?

        chosen.uniq
      end

      def default_actions
        @preset&.actions || Catalog::ACTIONS.keys
      end

      def assert_override_keys!
        extra = (@names.keys + @descriptions.keys + @titles.keys).uniq - actions
        return if extra.empty?

        raise configuration_error("Unknown messages API actions: #{extra.join(', ')}")
      end

      def assert_plan_unique!
        assert_unique("names", &:name)
        assert_unique("paths") { |endpoint| [endpoint.verb, endpoint.path] }
      end

      def assert_unique(label, &key)
        collision = endpoints.map { |endpoint| key.call(endpoint) }.tally.find { |_item, count| count > 1 }
        return unless collision

        raise configuration_error("Messages API #{label} collide: #{Array(collision.first).join(' ')}")
      end

      def identical?(endpoint)
        existing = registry[endpoint.name]
        return false unless existing

        existing.http_verb == endpoint.verb && existing.path == endpoint.path
      end

      def assert_available!(endpoint)
        assert_name_free!(endpoint)
        assert_path_free!(endpoint)
      end

      def assert_name_free!(endpoint)
        return if registry[endpoint.name].nil?

        raise configuration_error("API endpoint #{endpoint.name} is already registered")
      end

      def assert_path_free!(endpoint)
        taken = registry.all.find { |existing| existing.http_verb == endpoint.verb && existing.path == endpoint.path }
        return if taken.nil?

        verb = endpoint.verb.to_s.upcase
        raise configuration_error("API endpoint path #{verb} #{endpoint.path} is already registered")
      end

      def write_all(pending)
        pending.each { |endpoint| Draft.write(self, endpoint) }
      end
    end

    class Draft
      SEGMENT = /\A[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?\z/i
      TOOL_NAME = /\A[A-Za-z][A-Za-z0-9_.-]*\z/
      RESERVED_NAMES = %w[list show create update delete capability_action describe].freeze
      SERIALIZER = ->(result) { result }
      Endpoint = Data.define(
        :name, :verb, :path, :handler, :role, :recordable_type,
        :fields, :title, :description, :tags, :tag_group, :id_description
      )

      def self.build(placement, action)
        new(placement, action).endpoint
      end

      def self.write(placement, endpoint)
        kwargs = {
          api: placement.api, http_verb: endpoint.verb, path: endpoint.path, handler: endpoint.handler,
          serializer: SERIALIZER, required_role: endpoint.role,
          input_contract: { reject_unknown: false, fields: endpoint.fields },
          openapi: openapi(endpoint)
        }
        kwargs[:recordable_type] = endpoint.recordable_type if endpoint.recordable_type
        ::RecordingStudioApi.register_endpoint(endpoint.name, **kwargs)
      end

      def self.openapi(endpoint)
        document = {
          title: endpoint.title, summary: endpoint.title,
          description: endpoint.description, tags: endpoint.tags
        }
        document[:tag] = { group: endpoint.tag_group } if endpoint.tag_group.present?
        parameters = path_parameters(endpoint)
        document[:parameters] = parameters if parameters
        document
      end

      def self.path_parameters(endpoint)
        return if endpoint.id_description.blank?

        [{
          name: "id", in: "path", required: true,
          schema: { type: "string" }, description: endpoint.id_description
        }]
      end

      def initialize(placement, action)
        @placement = placement
        @action = action
        @spec = Catalog.fetch(action)
      end

      def endpoint
        Endpoint.new(
          name: endpoint_name, verb: @spec.fetch(:verb), path: full_path,
          handler: BoundAction.new(@spec.fetch(:handler), @placement, @action),
          role: @spec.fetch(:role), recordable_type: recordable_type,
          fields: Catalog.conversation_fields(@action, parent: @placement.parent?),
          title: title, description: description,
          tags: @placement.tags, tag_group: @placement.tag_group, id_description: id_description
        )
      end

      private

      def endpoint_name
        chosen = @placement.names.fetch(@action, default_name)
        check_name!(chosen.to_s)
      end

      def default_name
        suffix = @placement.preset&.names&.fetch(@action, @action) || @action
        "#{@placement.at}_#{suffix}"
      end

      def check_name!(name)
        if RESERVED_NAMES.include?(name)
          listed = RESERVED_NAMES.join(", ")
          raise error("#{name} is reserved for an MCP tree tool (#{listed})")
        end
        return name if name.match?(TOOL_NAME)

        raise error("API endpoint name #{name} must start with a letter")
      end

      def full_path
        tail = @placement.parent? ? ":id/#{@spec.fetch(:parent_path)}" : @spec.fetch(:singleton_path)
        "#{@placement.at}/#{tail}"
      end

      def recordable_type
        return @placement.mount_binding.recordable_type if @placement.parent?
        return MESSAGE_GROUP_TYPE if @spec.fetch(:singleton_path).include?(":id")

        nil
      end

      def title
        @placement.titles[@action] || @placement.preset&.titles&.fetch(@action, nil) || @spec.fetch(:title)
      end

      def description
        chosen = @placement.descriptions[@action]
        return chosen if chosen

        @placement.preset&.descriptions&.fetch(@action, nil) || @spec.fetch(:description)
      end

      def id_description
        return "The parent recording id. The handler loads that parent's message center." if @placement.parent?
        return conversation_id_description if @spec.fetch(:singleton_path).include?(":id")

        nil
      end

      def conversation_id_description
        return "The conversation id from list_my_messages." if @placement.actor_inbox?

        "The conversation id from a list or create response on this message center."
      end

      def error(message)
        ::RecordingStudioApi::ConfigurationError.new(message)
      end
    end

    class Segment
      def self.normalize(at, api)
        segment = at.to_s
        raise error("at must be one path segment, like support or press_centers") unless segment.match?(Draft::SEGMENT)

        reject_resource!(segment, api)
        segment
      end

      def self.reject_resource!(segment, api)
        type = resource_type(segment, api)
        return if type.blank?

        message = "at #{segment} is the API resource for #{type}. " \
                  "A placed path cannot start with a recordable resource name."
        raise error(message)
      end

      def self.resource_type(segment, api)
        return unless ::RecordingStudioApi.respond_to?(:recordable_type_for_resource)

        ::RecordingStudioApi.recordable_type_for_resource(segment, api: api)
      rescue ::RecordingStudioApi::ConfigurationError
        nil
      end

      def self.error(message)
        ::RecordingStudioApi::ConfigurationError.new(message)
      end
    end
  end
end
