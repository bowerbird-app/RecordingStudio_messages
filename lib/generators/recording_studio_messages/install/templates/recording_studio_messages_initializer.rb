# frozen_string_literal: true

RecordingStudioMessages.configure do |config|
  # Hosts can set options here. Enable :messages on the types that should hold a mount:
  # include RecordingStudio::Capabilities::Messages.to
  # config.time_break_after = 15.minutes
end

# Messages does not register API endpoints. Place each surface on the API that should expose it.
# RecordingStudioMessages::Api.place(
#   api: :public,
#   at: :support,
#   mount: -> { support_mount_recording },
#   preset: :support
# )
