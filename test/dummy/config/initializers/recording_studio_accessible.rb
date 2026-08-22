# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User", "Agent" ]
  config.avatar_resolver = lambda do |holder|
    {
      name: holder.try(:name).presence || holder.try(:email).to_s.split("@").first.to_s.titleize
    }
  end
end
