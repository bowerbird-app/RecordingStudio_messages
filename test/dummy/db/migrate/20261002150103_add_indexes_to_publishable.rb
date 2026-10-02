class AddIndexesToPublishable < ActiveRecord::Migration[6.0]
  def change
    # Add composite index for recording_studio_publishable_publishables on status, publish_at, and unpublish_at
    add_index :recording_studio_publishable_publishables, [:status, :publish_at, :unpublish_at], name: 'index_publishables_on_status_and_publish_times'
  end
end