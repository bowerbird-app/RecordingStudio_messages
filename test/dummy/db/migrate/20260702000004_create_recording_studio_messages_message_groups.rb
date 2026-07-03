# frozen_string_literal: true

class CreateRecordingStudioMessagesMessageGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_messages_message_groups, id: :uuid do |t|
      t.string :title
      t.string :subject
      t.jsonb :metadata, null: false, default: {}
      t.datetime :last_message_at

      t.timestamps
    end

    add_index :recording_studio_messages_message_groups, :last_message_at
  end
end
