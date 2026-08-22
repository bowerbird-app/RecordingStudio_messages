# frozen_string_literal: true

module RecordingStudioMessages
  class Message < ApplicationRecord
    self.table_name = "recording_studio_messages"

    recording_studio_recordable label: "Message",
                                root: false,
                                allowed_parent_types: ["RecordingStudioMessages::MessageGroup"]

    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*", "application/pdf", "text/plain"],
      enabled_attachment_kinds: %i[image file]
    )

    validates :body, length: { maximum: 10_000 }
  end
end
