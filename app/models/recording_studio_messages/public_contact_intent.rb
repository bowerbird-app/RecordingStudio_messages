# frozen_string_literal: true

module RecordingStudioMessages
  class PublicContactIntent < ApplicationRecord
    self.table_name = "recording_studio_messages_public_contact_intents"

    LIFETIME = 24.hours

    validates :mount_recording_id, :user_id, :otp_challenge_id, :email, :submitted_name, :expires_at, presence: true
    validates :submitted_name, length: { maximum: 120 }
    validates :body, length: { maximum: 10_000 }, allow_nil: true
    validate :contact_intent_state

    before_create { self.created_at ||= Time.current }

    def fulfilled?
      message_group_id.present?
    end

    def open?
      !fulfilled? && expires_at > Time.current
    end

    def expired?
      !fulfilled? && expires_at <= Time.current
    end

    def group_recording
      return if message_group_id.blank?

      RecordingStudio::Recording.find(message_group_id)
    end

    private

    def contact_intent_state
      if message_group_id.present?
        errors.add(:body, "must be blank once the conversation exists") if body.present?
      elsif body.blank? || body.length > 10_000
        errors.add(:body, "must be present")
      end
    end
  end
end
