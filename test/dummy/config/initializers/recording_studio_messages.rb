# frozen_string_literal: true

RecordingStudioMessages.configure do |config|
  config.current_actor = -> { Current.actor }
  config.layout = "flat_pack_sidebar"

  config.messages :support_messages do |messages|
    messages.name = "Support messages"
    messages.container_type = "SupportMessages"
    messages.recipient_actor_types = ["User"]
    messages.recipient_search = lambda do |query:, limit:, **|
      User.where("email ILIKE :query", query: "%#{query}%").limit(limit)
    end
    messages.recipient_allowed = ->(recipient:, **) { recipient.is_a?(User) }
    messages.recipient_label = ->(recipient:) { recipient.email }
    messages.recipient_description = ->(recipient:) { recipient.email }
  end

  config.messages :site_messages do |messages|
    messages.name = "Site messages"
    messages.container_type = "SiteMessages"
    messages.create_group_authorization = {
      type: :action,
      action: :"recording_studio_messages.create_group"
    }
    messages.recipient_actor_types = ["User"]
    messages.recipient_search = lambda do |query:, limit:, **|
      User.where("email ILIKE :query", query: "%#{query}%").limit(limit)
    end
    messages.recipient_allowed = ->(recipient:, **) { recipient.is_a?(User) }
    messages.recipient_label = ->(recipient:) { recipient.email }
    messages.recipient_description = ->(recipient:) { recipient.email }
  end
end

RecordingStudioAccessible.define_action(:"recording_studio_messages.create_group") do |actor:, **|
  actor.present?
end
