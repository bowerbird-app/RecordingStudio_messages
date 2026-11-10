# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroup < ApplicationRecord
    self.table_name = "recording_studio_message_groups"

    recording_studio_recordable label: "Conversation",
                                root: false,
                                allowed_parent_types: ["RecordingStudioMessages::MessageMount"]

    RecordingStudio.enable_capability(:accessible, on: self)

    TITLE_MAX = 120

    validates :title, presence: true, length: { maximum: TITLE_MAX }
  end
end
