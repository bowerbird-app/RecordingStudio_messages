# frozen_string_literal: true

module RecordingStudioMessages
  class Message < ApplicationRecord
    self.table_name = "recording_studio_messages_messages"

    belongs_to :message_group, class_name: "RecordingStudioMessages::MessageGroup", optional: true

    def self.declare_recording_studio_recordable!
      recording_studio_recordable label: "Message",
                                  plural_label: "Messages",
                                  root: false,
                                  allowed_parent_types: ["RecordingStudioMessages::MessageGroup"]
    end

    def sender
      return if sender_type.blank? || sender_id.blank?

      sender_type.safe_constantize&.find_by(id: sender_id)
    end
  end
end
