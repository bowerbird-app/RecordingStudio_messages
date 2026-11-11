# frozen_string_literal: true

module RecordingStudioMessages
  module MountAccess
    MEMBERS = :members
    INHERITED = :inherited
    ALLOWED = [MEMBERS, INHERITED].freeze

    module_function

    def inherited?(mount_recording)
      mode(mount_recording) == INHERITED
    end

    def members?(mount_recording)
      mode(mount_recording) == MEMBERS
    end

    def mode(mount_recording)
      return MEMBERS unless mount_recording&.recordable_type == MESSAGE_MOUNT_TYPE

      parent = mount_recording.parent_recording
      return MEMBERS if parent.blank?

      normalize(message_options(parent.recordable_type)[:access])
    end

    def normalize(raw)
      return MEMBERS if raw.blank?

      mode = raw.to_sym
      return mode if ALLOWED.include?(mode)

      raise RecordingStudioMessages::Error, "Messages access must be :members or :inherited"
    end

    def message_options(parent_type)
      RecordingStudio.capability_options(:messages, for: parent_type) || {}
    end
  end
end
