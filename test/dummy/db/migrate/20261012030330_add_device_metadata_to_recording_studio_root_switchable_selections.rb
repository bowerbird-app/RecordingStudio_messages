# frozen_string_literal: true

class AddDeviceMetadataToRecordingStudioRootSwitchableSelections < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:recording_studio_root_switchable_selections)

    change_table :recording_studio_root_switchable_selections, bulk: true do |t|
      t.string :device_label, limit: 255 unless column_exists?(:recording_studio_root_switchable_selections, :device_label)
      t.string :device_platform, limit: 255 unless column_exists?(:recording_studio_root_switchable_selections, :device_platform)
      t.string :device_browser, limit: 255 unless column_exists?(:recording_studio_root_switchable_selections, :device_browser)
      t.string :device_type, limit: 255 unless column_exists?(:recording_studio_root_switchable_selections, :device_type)
      t.text :user_agent unless column_exists?(:recording_studio_root_switchable_selections, :user_agent)
    end
  end
end
