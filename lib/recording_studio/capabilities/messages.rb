# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Messages
      def self.to(**)
        RecordingStudio::Capabilities.include_for(:messages, **)
      end

      module RecordingMethods
        MESSAGE_MOUNT_TYPE = "RecordingStudioMessages::MessageMount"

        def message_mounts
          RecordingStudio::Recording.unscoped.where(
            parent_recording_id: id,
            recordable_type: MESSAGE_MOUNT_TYPE,
            trashed_at: nil
          )
        end

        def message_mount(key)
          expected_key = key.to_s
          message_mounts.includes(:recordable).detect do |recording|
            recording.recordable&.key == expected_key
          end
        end

        def ensure_message_mount(key, actor: nil)
          RecordingStudioMessages.ensure_mount(self, key: key, actor: actor)
        end
      end
    end
  end
end
