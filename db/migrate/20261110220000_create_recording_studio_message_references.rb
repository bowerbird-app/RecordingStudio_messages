# frozen_string_literal: true

class CreateRecordingStudioMessageReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_message_references, id: :uuid do |t|
      t.uuid :message_recording_id, null: false
      t.uuid :target_recording_id, null: false
      t.datetime :created_at, null: false

      t.index %i[message_recording_id target_recording_id],
              unique: true,
              name: "index_message_references_on_message_and_target"
      t.index :message_recording_id,
              name: "index_message_references_on_message_recording_id"
      t.index :target_recording_id,
              name: "index_message_references_on_target_recording_id"
    end
  end
end
