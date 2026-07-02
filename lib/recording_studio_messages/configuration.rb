# frozen_string_literal: true

module RecordingStudioMessages
  class ConfigurationError < StandardError; end

  class Configuration
    DEFAULT_CREATE_GROUP_AUTHORIZATION = { type: :container_access, role: :edit }.freeze
    DEFAULT_PAGE_SIZE = 25

    attr_accessor :current_actor, :layout, :default_page_size, :message_page_size

    def initialize
      @current_actor = nil
      @layout = "application"
      @default_page_size = DEFAULT_PAGE_SIZE
      @message_page_size = DEFAULT_PAGE_SIZE
      @messages = {}
    end

    def messages(key = nil)
      return @messages if key.nil?

      normalized_key = key.to_sym
      config = (@messages[normalized_key] ||= MessagesConfig.new(normalized_key))
      yield(config) if block_given?
      config
    end

    def message_config!(key)
      messages.fetch(key.to_sym) do
        raise ConfigurationError, "Unknown RecordingStudioMessages messages key: #{key.inspect}"
      end
    end

    def container_recordable_types
      messages.values.filter_map(&:container_type).uniq
    end

    def to_h
      {
        layout: layout,
        default_page_size: default_page_size,
        message_page_size: message_page_size,
        messages: messages.transform_values(&:to_h),
        container_recordable_types: container_recordable_types
      }
    end
  end

  class MessagesConfig
    attr_reader :key
    attr_accessor :name, :container_type, :create_group_authorization,
                  :recipient_actor_types, :recipient_search, :recipient_allowed,
                  :recipient_label, :recipient_description, :creator_role,
                  :recipient_role, :include_creator, :max_recipients,
                  :minimum_recipient_query_length, :recipient_search_limit,
                  :page_size, :message_page_size

    def initialize(key)
      @key = key.to_sym
      @name = key.to_s.humanize
      @container_type = nil
      @create_group_authorization = nil
      @recipient_actor_types = []
      @recipient_search = nil
      @recipient_allowed = nil
      @recipient_label = nil
      @recipient_description = nil
      @creator_role = :admin
      @recipient_role = :edit
      @include_creator = true
      @max_recipients = 50
      @minimum_recipient_query_length = 2
      @recipient_search_limit = 10
      @page_size = nil
      @message_page_size = nil
    end

    def effective_create_group_authorization
      (create_group_authorization || Configuration::DEFAULT_CREATE_GROUP_AUTHORIZATION).symbolize_keys
    end

    def validate!
      raise ConfigurationError, "messages #{key.inspect} requires container_type" if container_type.blank?

      validate_create_group_authorization!
      true
    end

    def to_h
      {
        key: key,
        name: name,
        container_type: container_type,
        create_group_authorization: effective_create_group_authorization,
        recipient_actor_types: recipient_actor_types,
        creator_role: creator_role,
        recipient_role: recipient_role,
        include_creator: include_creator,
        max_recipients: max_recipients,
        minimum_recipient_query_length: minimum_recipient_query_length,
        recipient_search_limit: recipient_search_limit
      }
    end

    private

    def validate_create_group_authorization!
      auth = effective_create_group_authorization
      case auth.fetch(:type, :container_access).to_sym
      when :container_access
        role = auth.fetch(:role, :edit).to_sym
        return if %i[view edit admin].include?(role)

        raise ConfigurationError, "Unsupported create group role for #{key}: #{role.inspect}"
      when :action
        raise ConfigurationError, "Action authorization for #{key} requires :action" if auth[:action].blank?
      else
        raise ConfigurationError, "Unsupported create group authorization type for #{key}: #{auth[:type].inspect}"
      end
    end
  end
end
