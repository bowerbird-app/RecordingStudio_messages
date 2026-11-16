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
    "RecordingStudioTermsAndConditions::Library",
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
    "RecordingStudioApi::ApiAccessToken"
  ]
  # Core 7.3 raises MissingRecordableDeclaration if AdminApi is listed before
  # it declares. API declares it only when an admin root type is loaded.
  register_admin_api = proc do
    next unless defined?(RecordingStudioApi::Engine)
    next if RecordingStudioApi::Engine.admin_root_recordable_type_names.empty?

    if defined?(RecordingStudioApi::AdminApi) &&
        RecordingStudioApi::AdminApi.respond_to?(:declare_recordable!) &&
        defined?(RecordingStudio::RecordableDeclarations) &&
        !RecordingStudio::RecordableDeclarations.declarations.key?("RecordingStudioApi::AdminApi")
      RecordingStudioApi::AdminApi.declare_recordable!
    end

    type_names = Array(RecordingStudio.configuration.recordable_types).map(&:to_s)
    next if type_names.include?("RecordingStudioApi::AdminApi")

    RecordingStudio.configuration.recordable_types = type_names + [ "RecordingStudioApi::AdminApi" ]
  end
  register_admin_api.call
  Rails.application.config.to_prepare(&register_admin_api)

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
