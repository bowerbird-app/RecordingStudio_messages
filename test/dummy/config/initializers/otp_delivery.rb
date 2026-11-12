# frozen_string_literal: true

# The dummy has no mailer. Public contact still needs a channel so Users can
# hand the code to Notifications. Tests replace these adapters.
adapter = Class.new do
  def deliver(notification:, delivery:)
    delivery.mark_delivered! if delivery.respond_to?(:mark_delivered!)
    notification
  end
end.new

registry = RecordingStudioNotifications.channels
%i[email push].each do |name|
  next if registry.registered?(name)

  RecordingStudioNotifications.register_channel(name, adapter)
end
