# frozen_string_literal: true

if defined?(RecordingStudioMessages::Engine)
  pin_all_from RecordingStudioMessages::Engine.root.join(
    "app/javascript/recording_studio_messages/controllers"
  ),
               under: "controllers/recording_studio_messages",
               to: "recording_studio_messages/controllers",
               preload: false
end
