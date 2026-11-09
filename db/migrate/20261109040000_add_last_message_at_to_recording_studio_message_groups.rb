# frozen_string_literal: true

class AddLastMessageAtToRecordingStudioMessageGroups < ActiveRecord::Migration[8.1]
  def up
    add_column :recording_studio_message_groups, :last_message_at, :datetime
    add_index :recording_studio_message_groups, :last_message_at,
              name: "index_recording_studio_message_groups_on_last_message_at"

    execute <<~SQL.squish
      UPDATE recording_studio_message_groups
      SET last_message_at = (
        SELECT MAX(messages.created_at)
        FROM recording_studio_recordings groups
        INNER JOIN recording_studio_recordings messages
          ON messages.parent_recording_id = groups.id
          AND messages.recordable_type = 'RecordingStudioMessages::Message'
          AND messages.trashed_at IS NULL
        WHERE groups.recordable_id = recording_studio_message_groups.id
          AND groups.recordable_type = 'RecordingStudioMessages::MessageGroup'
      )
    SQL
  end

  def down
    remove_index :recording_studio_message_groups,
                 name: "index_recording_studio_message_groups_on_last_message_at"
    remove_column :recording_studio_message_groups, :last_message_at
  end
end
