module ApplicationHelper
  include RecordingStudioMessages::PanelHelper
  include RecordingStudioMessages::InboxHelper
  include RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
end
