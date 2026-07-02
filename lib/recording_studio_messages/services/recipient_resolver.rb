# frozen_string_literal: true

module RecordingStudioMessages
  class RecipientResolver
    def initialize(messages_config:, submitted_recipients:, actor:, container_recording:, message_group_recording: nil, controller: nil)
      @messages_config = messages_config
      @submitted_recipients = Array(submitted_recipients)
      @actor = actor
      @container_recording = container_recording
      @message_group_recording = message_group_recording
      @controller = controller
    end

    def recipients
      @recipients ||= resolve
    end

    private

    def resolve
      allowed_types = Array(@messages_config.recipient_actor_types).map(&:to_s)
      return [] if allowed_types.empty?

      @submitted_recipients.filter_map { |attrs| resolve_one(attrs, allowed_types) }
                           .uniq { |recipient| [recipient.class.name, recipient.id.to_s] }
                           .first(@messages_config.max_recipients.to_i)
                           .select { |recipient| allowed?(recipient) }
    end

    def resolve_one(attrs, allowed_types)
      type = value(attrs, :recipient_type).to_s
      id = value(attrs, :recipient_id)
      return unless allowed_types.include?(type) && id.present?

      type.safe_constantize&.find_by(id: id)
    end

    def allowed?(recipient)
      hook = @messages_config.recipient_allowed
      return false unless hook.respond_to?(:call)

      hook.call(
        recipient: recipient,
        actor: @actor,
        container_recording: @container_recording,
        message_group_recording: @message_group_recording,
        controller: @controller
      ) == true
    end

    def value(attrs, key)
      attrs.respond_to?(:[]) ? attrs[key] || attrs[key.to_s] : nil
    end
  end
end
