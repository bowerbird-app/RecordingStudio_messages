# frozen_string_literal: true

RecordingStudioMessages.configure do |config|
  # Hosts can set options here. Enable :messages on the types that should hold a mount:
  # include RecordingStudio::Capabilities::Messages.to
  # config.time_break_after = 15.minutes
end

# Place each message-center surface on the API that should expose it.
# The engine places My Messages on :public. :support stays off MCP.
# RecordingStudioMessages::Api.place(
#   api: :public,
#   at: :support,
#   mount: -> { support_mount_recording },
#   preset: :support
# )
