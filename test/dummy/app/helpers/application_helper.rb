module ApplicationHelper
  include RecordingStudioMessages::CopyHelper
  include RecordingStudioMessages::PanelHelper
  include DummyMessagesPanelHelper
  include RecordingStudioMessages::InboxHelper
  include DummyMessagesListHelper
  include RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
  include DummyLayoutHelper
end
