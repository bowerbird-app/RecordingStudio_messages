# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "Mailbox",
    "AdminRoot",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioMessages::MessageMount",
    "RecordingStudioMessages::MessageGroup",
    "RecordingStudioMessages::Message",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioTermsAndConditions::Terms",
    "RecordingStudioTermsAndConditions::Section",
    "RecordingStudioTermsAndConditions::Clause",
    "RecordingStudioPublishable::Publishable",
    "RecordingStudioAttachable::Attachment"
  ]
  config.recordable_types += [
    "RecordingStudio::Access",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioApi::ApiCredential",
    "RecordingStudioApi::ApiAccessToken",
    "RecordingStudioApi::AdminApi"
  ]

  config.require_recordable_declarations = true

  # Core 7 denies a write unless this is set. Seeds and tests write as the
  # host, including agents. A present actor may write, including a new root
  # where root_recording is nil.
  config.authorize_write = ->(actor:, **) { actor.present? }

  config.app_name = "Dummy host" if config.respond_to?(:app_name=)

  config.actor = -> { Current.actor }

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
