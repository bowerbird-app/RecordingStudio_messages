# frozen_string_literal: true

module RecordingStudioMessages
  class MessageRead < ApplicationRecord
    self.table_name = "recording_studio_message_reads"

    ACTOR_GROUP_INDEX = :index_message_reads_on_actor_and_group

    validates :actor_type, :actor_id, :message_group_recording_id, :last_read_at, presence: true
  end
end
