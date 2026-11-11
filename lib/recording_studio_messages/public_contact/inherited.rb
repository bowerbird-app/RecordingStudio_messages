# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    class << self
      private

      def fulfill_inherited!(mount:, contact:, title:, body:, recipients:, tags:)
        ActiveRecord::Base.transaction do
          group = open_inherited_contact_group(mount, contact, title, tags)
          message = send_contact_message(group, contact, body, notify: false)
          notify_resolver_recipients(group, message, contact, body, recipients)
          group
        end
      end

      def open_inherited_contact_group(mount, contact, title, tags)
        group = nil
        RecordingStudioMessages.allow_membership_change do
          group = RecordingStudioMessages.create_group(
            mount, title: title.to_s.truncate(120), actor: contact, tags: tags
          )
          grant_sender_edit!(group, contact)
        end
        group
      end

      def grant_sender_edit!(group, contact)
        manager = manager_for_inherited_grant(group, contact)
        raise Error, Copy.t("errors.cannot_send") if manager.blank?

        grant_edit!(group, contact, manager)
      end

      def manager_for_inherited_grant(group, contact)
        return contact if admin_on?(contact, group)

        ancestor = group
        while ancestor
          actor = admin_holder_on(ancestor, group)
          return actor if actor

          ancestor = ancestor.parent_recording
        end
        nil
      end

      def admin_holder_on(recording, group)
        RecordingStudioAccessible.access_recordings_for(recording).each do |access_recording|
          actor = access_recording.recordable&.actor
          return actor if actor.present? && admin_on?(actor, group)
        end
        nil
      end

      def admin_on?(actor, recording)
        RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :admin)
      end

      def notify_resolver_recipients(group, message, contact, body, recipients)
        return if message.blank?

        Services::NotifyGrantedActors.call(
          group_recording: group,
          message_recording: message,
          actor: contact,
          body: body.to_s.truncate(120),
          url: RecordingStudioMessages::Engine.routes.url_helpers.message_group_path(group),
          recipients: Array(recipients).compact
        )
      end
    end
  end
end
