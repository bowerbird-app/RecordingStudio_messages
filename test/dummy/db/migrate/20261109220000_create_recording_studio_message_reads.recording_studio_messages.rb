# frozen_string_literal: true

class CreateRecordingStudioMessageReads < ActiveRecord::Migration[8.1]
  def up
    create_table :recording_studio_message_reads, id: :uuid do |t|
      t.string :actor_type, null: false
      t.uuid :actor_id, null: false
      t.uuid :message_group_recording_id, null: false
      t.datetime :last_read_at, null: false
      t.uuid :last_read_message_recording_id
      t.timestamps

      t.index %i[actor_type actor_id message_group_recording_id],
              unique: true,
              name: "index_message_reads_on_actor_and_group"
      t.index :message_group_recording_id,
              name: "index_message_reads_on_message_group_recording_id"
    end

    RecordingStudioMessages::Services::MessageReads.backfill_existing_as_read!
  end

  def down
    drop_table :recording_studio_message_reads
  end
end
