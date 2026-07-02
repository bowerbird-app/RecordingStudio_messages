# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroup < ApplicationRecord
    self.table_name = "recording_studio_messages_message_groups"

    has_many :messages, class_name: "RecordingStudioMessages::Message", dependent: :destroy

    def self.declare_recording_studio_recordable!
      recording_studio_recordable label: "Message group",
                                  plural_label: "Message groups",
                                  root: false,
                                  allowed_parent_types: RecordingStudioMessages.configuration.container_recordable_types
      RecordingStudio.enable_capability(:accessible, on: self) if RecordingStudio.respond_to?(:enable_capability)
    end

    def display_title
      title.presence || subject.presence || "Message group"
    end
  end
end
