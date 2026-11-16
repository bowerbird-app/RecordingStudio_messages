# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User", "Agent" ]
  config.access_actor_types += [ "RecordingStudioApi::ApiClient" ]
  # Accessible 0.45's page authorizer allows an admin grant on this root.
  # A missing resolver denies the page.
  config.admin_root_resolver = lambda do
    workspace = Workspace.find_by(name: "Studio Workspace")
    next unless workspace

    RecordingStudio.root_recording_for(workspace)
  end
  config.avatar_resolver = lambda do |holder|
    {
      name: holder.try(:name).presence || holder.try(:email).to_s.split("@").first.to_s.titleize
    }
  end
end
