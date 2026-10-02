# frozen_string_literal: true

RecordingStudioMessages.configure do |config|
  config.public_contact_recipient_resolver = lambda { |mount_recording:, actor:|
    next [] if mount_recording.blank? || actor.blank?

    [User.find_by(email: "admin@admin.com")].compact
  }
end
