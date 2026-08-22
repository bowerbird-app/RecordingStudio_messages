module ApplicationHelper
  include RecordingStudioMessages::PanelHelper
  include RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
end
