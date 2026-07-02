# frozen_string_literal: true

class CreateRecordingStudioMessagesMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_messages_messages, id: :uuid do |t|
      t.uuid :message_group_id
      t.string :sender_type, null: false
      t.uuid :sender_id, null: false
      t.text :body, null: false
      t.jsonb :content, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :recording_studio_messages_messages, :message_group_id
    add_index :recording_studio_messages_messages, %i[sender_type sender_id]
    add_index :recording_studio_messages_messages, :created_at
  end
end
