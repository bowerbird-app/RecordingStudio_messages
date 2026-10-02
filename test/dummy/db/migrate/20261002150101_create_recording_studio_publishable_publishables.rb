# frozen_string_literal: true

class CreateRecordingStudioPublishablePublishables < ActiveRecord::Migration[8.1]
  UNIQUE_CHILD_INDEX = "index_rs_publishable_child_per_parent"
  CANONICAL_URL_INDEX = "index_rs_publishables_on_canonical_url"
  SLUG_INDEX = "index_rs_publishables_on_slug"
  RECORDABLE_TYPE = "RecordingStudioPublishable::Publishable"

  def unique_child_index_where_clause
    if column_exists?(:recording_studio_recordings, :trashed_at)
      "recordable_type = '#{RECORDABLE_TYPE}' AND trashed_at IS NULL"
    else
      "recordable_type = '#{RECORDABLE_TYPE}'"
    end
  end

  def change
    create_table :recording_studio_publishable_publishables, id: :uuid do |t|
      t.string :slug, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :publish_at
      t.datetime :unpublish_at
      t.string :time_zone
      t.string :seo_title
      t.text :seo_description
      t.string :canonical_url
      t.string :meta_robots
      t.string :social_title
      t.text :social_description
      t.timestamps
    end

    add_index :recording_studio_publishable_publishables, :slug, name: SLUG_INDEX
    add_index :recording_studio_publishable_publishables, %i[status publish_at unpublish_at],
              name: "index_rs_publishables_on_state_window"
    add_index :recording_studio_publishable_publishables, :canonical_url, name: CANONICAL_URL_INDEX

    add_index :recording_studio_recordings,
              :parent_recording_id,
              unique: true,
              name: UNIQUE_CHILD_INDEX,
              where: unique_child_index_where_clause
  end
end
