# frozen_string_literal: true

class CreateRecordingStudioMessagesPublicContactIntents < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_messages_public_contact_intents, id: :uuid do |t|
      t.uuid :mount_recording_id, null: false
      t.uuid :user_id, null: false
      t.uuid :otp_challenge_id, null: false
      t.uuid :message_group_id
      t.string :email, null: false
      t.string :submitted_name, null: false
      t.text :body
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false

      t.index :message_group_id,
              unique: true,
              where: "message_group_id IS NOT NULL",
              name: "index_public_contact_intents_on_message_group"

      t.check_constraint <<~SQL.squish, name: "contact_intent_state"
        (message_group_id IS NULL AND body IS NOT NULL AND char_length(body) BETWEEN 1 AND 10000)
        OR
        (message_group_id IS NOT NULL AND body IS NULL)
      SQL
    end
  end
end
