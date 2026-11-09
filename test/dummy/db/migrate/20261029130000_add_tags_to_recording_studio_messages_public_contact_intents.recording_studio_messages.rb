# frozen_string_literal: true

class AddTagsToRecordingStudioMessagesPublicContactIntents < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_messages_public_contact_intents, :tags, :jsonb, null: false, default: {}
  end
end
