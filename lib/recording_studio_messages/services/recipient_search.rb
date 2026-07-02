# frozen_string_literal: true

module RecordingStudioMessages
  class RecipientSearch
    def initialize(messages_config:, query:, actor:, container_recording:, controller: nil)
      @messages_config = messages_config
      @query = query.to_s
      @actor = actor
      @container_recording = container_recording
      @controller = controller
    end

    def results
      return [] unless searchable?

      Array(search_results).first(limit).select { |recipient| allowed?(recipient) }.map { |recipient| shape(recipient) }
    end

    private

    def searchable?
      @query.length >= @messages_config.minimum_recipient_query_length.to_i &&
        @messages_config.recipient_search.respond_to?(:call) &&
        @messages_config.recipient_allowed.respond_to?(:call) &&
        Array(@messages_config.recipient_actor_types).any?
    end

    def search_results
      @messages_config.recipient_search.call(
        query: @query,
        actor: @actor,
        container_recording: @container_recording,
        controller: @controller,
        limit: limit
      )
    end

    def allowed?(recipient)
      Array(@messages_config.recipient_actor_types).map(&:to_s).include?(recipient.class.name) &&
        @messages_config.recipient_allowed.call(
          recipient: recipient,
          actor: @actor,
          container_recording: @container_recording,
          message_group_recording: nil,
          controller: @controller
        ) == true
    end

    def shape(recipient)
      {
        type: recipient.class.name,
        id: recipient.id.to_s,
        label: label_for(recipient),
        description: description_for(recipient)
      }
    end

    def label_for(recipient)
      hook = @messages_config.recipient_label
      return hook.call(recipient: recipient).to_s if hook.respond_to?(:call)
      return recipient.name.to_s if recipient.respond_to?(:name) && recipient.name.present?
      return recipient.email.to_s if recipient.respond_to?(:email) && recipient.email.present?

      "#{recipient.model_name.human} #{recipient.id}"
    end

    def description_for(recipient)
      hook = @messages_config.recipient_description
      return hook.call(recipient: recipient).to_s if hook.respond_to?(:call)
      return recipient.email.to_s if recipient.respond_to?(:email)

      nil
    end

    def limit
      @limit ||= [@messages_config.recipient_search_limit.to_i, 1].max
    end
  end
end
