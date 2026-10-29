# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupTag < ApplicationRecord
    self.table_name = "recording_studio_message_group_tags"

    validates :message_group_recording_id, :key, :tagged_recording_id, presence: true
    validates :key, uniqueness: { scope: :message_group_recording_id }

    before_create { self.created_at ||= Time.current }
  end
end
