# frozen_string_literal: true

class AddSocialImageAttachmentRecordingIdToPublishables < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_publishable_publishables, :social_image_attachment_recording_id, :uuid
    add_index :recording_studio_publishable_publishables,
              :social_image_attachment_recording_id,
              name: "index_rs_publishables_on_social_image_attachment_recording_id"
    add_foreign_key :recording_studio_publishable_publishables,
                    :recording_studio_recordings,
                    column: :social_image_attachment_recording_id,
                    name: "fk_rs_publishables_social_image_attachment_recording"
  end
end