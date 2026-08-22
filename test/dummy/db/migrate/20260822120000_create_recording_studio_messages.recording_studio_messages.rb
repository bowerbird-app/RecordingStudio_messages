# frozen_string_literal: true

class CreateRecordingStudioMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_message_mounts, id: :uuid do |t|
      t.string :key, null: false
      t.datetime :created_at, null: false

      t.index :key
    end

    create_table :recording_studio_message_groups, id: :uuid do |t|
      t.string :title, null: false
      t.datetime :created_at, null: false
    end

    create_table :recording_studio_messages, id: :uuid do |t|
      t.text :body
      t.datetime :created_at, null: false
    end
  end
end
