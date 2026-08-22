# frozen_string_literal: true

module RecordingStudioMessages
  class MessageMount < ApplicationRecord
    self.table_name = "recording_studio_message_mounts"

    recording_studio_recordable label: "Messages",
                                root: false

    validates :key, presence: true
  end
end
