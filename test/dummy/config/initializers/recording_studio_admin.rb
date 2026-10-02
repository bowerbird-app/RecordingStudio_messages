# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.find_by(recordable: admin_root, trashed_at: nil)
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
end

# Admin authorizes against the Admin root. Root Switchable's current root is a
# workspace, and Admin refuses the request when those two recordings differ.
# Skip that resolution on the admin engine so the workspace switcher stays put.
Rails.application.config.to_prepare do
  controller = RecordingStudioAdmin::ApplicationController
  next if controller.instance_variable_get(:@dummy_skips_workspace_root)
  next unless controller.respond_to?(:skip_recording_studio_root_resolution)

  controller.skip_recording_studio_root_resolution
  controller.instance_variable_set(:@dummy_skips_workspace_root, true)
end
