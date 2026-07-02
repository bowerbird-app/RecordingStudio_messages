# frozen_string_literal: true

RecordingStudioMessages.configure do |config|
  config.current_actor = -> { Current.actor }
  config.layout = "application"

  # Example hierarchy-owned container. Creation defaults to ordinary :edit access on the container recording.
  config.messages :support_messages do |messages|
    messages.name = "Support messages"
    messages.container_type = "SupportMessages"
    messages.recipient_actor_types = ["User"]
    # Configure recipient_search and recipient_allowed before enabling in production.
  end

  # Example shared-root/private-child container. Use action authorization only when broad
  # container :edit access would expose every private message group under the root.
  config.messages :site_messages do |messages|
    messages.name = "Site messages"
    messages.container_type = "SiteMessages"
    messages.create_group_authorization = {
      type: :action,
      action: :"recording_studio_messages.create_group"
    }
    messages.recipient_actor_types = ["User"]
  end
end

# Optional shared-root action policy. Registration is handled by the gem; this policy grants nothing
# unless a messages config uses type: :action.
# RecordingStudioAccessible.define_action(:"recording_studio_messages.create_group") do |actor:, recording:, context:, controller:, **|
#   actor.present? && actor.respond_to?(:subscribed?) && actor.subscribed?
# end
