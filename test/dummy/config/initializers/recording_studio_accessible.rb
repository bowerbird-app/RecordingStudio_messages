# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User", "Agent" ]
  config.access_actor_types += [ "RecordingStudioApi::ApiClient" ]
  config.admin_root_resolver = lambda do
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.kept.find_by(recordable: admin_root)
  end
  config.avatar_resolver = lambda do |holder|
    {
      name: holder.try(:name).presence || holder.try(:email).to_s.split("@").first.to_s.titleize
    }
  end
end
