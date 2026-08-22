# frozen_string_literal: true

RecordingStudioNotifications.configure do |config|
  config.actor_resolver = -> { Current.actor }
  config.deliver_later = false
end
