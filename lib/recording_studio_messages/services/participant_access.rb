# frozen_string_literal: true

module RecordingStudioMessages
  class ParticipantAccess
    def initialize(messages_config:, message_group_recording:, creator:, recipients: [])
      @messages_config = messages_config
      @message_group_recording = message_group_recording
      @creator = creator
      @recipients = recipients
    end

    def grant!
      granted = []
      if @messages_config.include_creator && @creator
        grant_once!(granted, @creator, @messages_config.creator_role)
      end
      @recipients.each do |recipient|
        next if same_actor?(recipient, @creator) && @messages_config.include_creator

        grant_once!(granted, recipient, @messages_config.recipient_role)
      end
    end

    private

    def grant_once!(granted, actor, role)
      key = [actor.class.name, actor.id.to_s]
      return if granted.include?(key)

      RecordingStudioAccessible.grant_access(recording: @message_group_recording, actor: actor, role: role)
      granted << key
    end

    def same_actor?(left, right)
      left && right && left.class.name == right.class.name && left.id.to_s == right.id.to_s
    end
  end
end
