# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupCreator
    Result = Struct.new(:message_group_recording, :message_recording, :recipients, keyword_init: true)

    def initialize(messages_config:, actor:, container_recording:, params:, controller: nil)
      @messages_config = messages_config
      @actor = actor
      @container_recording = container_recording
      @params = params
      @controller = controller
    end

    def create!
      ActiveRecord::Base.transaction do
        authorize!
        recipients = resolve_recipients
        group_recording = create_group_recording!
        ParticipantAccess.new(
          messages_config: @messages_config,
          message_group_recording: group_recording,
          creator: @actor,
          recipients: recipients
        ).grant!
        message_recording = MessageCreator.new(
          message_group_recording: group_recording,
          actor: @actor,
          body: value(:body),
          content: value(:content) || {},
          metadata: value(:metadata) || {}
        ).create!
        Result.new(message_group_recording: group_recording, message_recording: message_recording, recipients: recipients)
      end
    end

    private

    def authorize!
      return if CreateGroupAuthorizer.new(
        messages_config: @messages_config,
        actor: @actor,
        container_recording: @container_recording,
        controller: @controller
      ).authorized?

      raise ActiveRecord::RecordNotSaved, "Not authorized to create message group"
    end

    def resolve_recipients
      RecipientResolver.new(
        messages_config: @messages_config,
        submitted_recipients: value(:recipients),
        actor: @actor,
        container_recording: @container_recording,
        controller: @controller
      ).recipients
    end

    def create_group_recording!
      @container_recording.record(RecordingStudioMessages::MessageGroup, actor: @actor, parent_recording: @container_recording) do |group|
        group.title = value(:title)
        group.subject = value(:subject)
        group.metadata = value(:group_metadata) || {}
      end
    end

    def value(key)
      @params.respond_to?(:[]) ? @params[key] || @params[key.to_s] : nil
    end
  end
end
