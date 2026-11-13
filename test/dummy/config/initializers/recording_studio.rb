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

  # Recording Studio 6.5 fails closed without an authorizer. Dummy seeds and
  # tests write as the host, including agents, so keep those writes open.
  config.allow_unauthorized_writes = true

  config.app_name = "Dummy host" if config.respond_to?(:app_name=)

  config.actor = -> { Current.actor }

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
