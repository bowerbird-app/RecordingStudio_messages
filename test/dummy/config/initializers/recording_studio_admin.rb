# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  # Site sections need blast radius :site. Admin allows that only when this
  # recording is the Accessible admin root. That root is Studio Workspace.
  config.access_recording_resolver = lambda do |_context|
    workspace = Workspace.find_by(name: "Studio Workspace")
    next unless workspace

    RecordingStudio.root_recording_for(workspace)
  end
end

# Root Switchable's current root can be a different workspace. Admin refuses
# the request when that root and the access recording differ. Skip that
# resolution on the admin engine so the workspace switcher stays put.
Rails.application.config.to_prepare do
  controller = RecordingStudioAdmin::ApplicationController
  next if controller.instance_variable_get(:@dummy_skips_workspace_root)
  next unless controller.respond_to?(:skip_recording_studio_root_resolution)

  controller.skip_recording_studio_root_resolution
  controller.instance_variable_set(:@dummy_skips_workspace_root, true)
end
