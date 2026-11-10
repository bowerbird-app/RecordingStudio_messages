# frozen_string_literal: true

module RecordingStudioMessages
  class MessageReference < ApplicationRecord
    self.table_name = "recording_studio_message_references"

    validates :message_recording_id, :target_recording_id, presence: true
    validates :target_recording_id, uniqueness: { scope: :message_recording_id }
  end
end
