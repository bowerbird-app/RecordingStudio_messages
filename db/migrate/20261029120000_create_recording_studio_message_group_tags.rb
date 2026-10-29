# frozen_string_literal: true

class CreateRecordingStudioMessageGroupTags < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_message_group_tags, id: :uuid do |t|
      t.uuid :message_group_recording_id, null: false
      t.string :key, null: false
      t.uuid :tagged_recording_id, null: false
      t.datetime :created_at, null: false

      t.index %i[message_group_recording_id key],
              unique: true,
              name: "index_message_group_tags_on_group_and_key"
      t.index %i[key tagged_recording_id],
              name: "index_message_group_tags_on_key_and_tagged_recording"
    end
  end
end
