class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  include RecordingStudio::Capabilities::Messages.to(keys: [ :support ])
end

