class Mailbox < ApplicationRecord
  recording_studio_recordable label: "Mailbox", root: false, allowed_parent_types: [ "Workspace" ]
  include RecordingStudio::Capabilities::Messages.to
end
