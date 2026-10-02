# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    class << self
      private

      def send_now(mount, actor, text)
        group = fulfill!(
          mount: mount,
          contact: actor,
          title: signed_in_title(actor),
          body: text,
          recipients: recipients_for(mount, actor)
        )
        Outcome.new(group_recording: group)
      end

      def fulfill!(mount:, contact:, title:, body:, recipients:)
        opener = opener_among(mount, recipients)
        raise Error, NO_RECIPIENT if opener.nil?

        ActiveRecord::Base.transaction do
          group = open_contact_group(mount, opener, contact, title, recipients)
          send_contact_message(group, contact, body)
          group
        end
      end

      def open_contact_group(mount, opener, contact, title, recipients)
        group = nil
        RecordingStudioMessages.allow_membership_change do
          group = RecordingStudioMessages.create_group(mount, title: title.to_s.truncate(120), actor: opener)
          grant_contact_members(group, opener, contact, recipients)
        end
        group
      end

      def grant_contact_members(group, opener, contact, recipients)
        # A second grant at :edit would replace the opener's :admin.
        grant_edit!(group, contact, opener) unless same_actor?(contact, opener)
        grant_other_recipients(group, opener, contact, recipients)
      end

      def grant_other_recipients(group, opener, contact, recipients)
        granted_ids = []
        Array(recipients).each do |recipient|
          next if skip_recipient?(recipient, opener, contact, granted_ids)

          grant_edit!(group, recipient, opener)
          granted_ids << recipient.id.to_s
        end
      end

      def skip_recipient?(recipient, opener, contact, granted_ids)
        same_actor?(recipient, opener) || same_actor?(recipient, contact) || granted_ids.include?(recipient.id.to_s)
      end

      def send_contact_message(group, contact, body)
        RecordingStudioMessages.send_message(
          group_recording: group,
          body: body,
          actor: contact,
          files: [],
          notify: true,
          url: RecordingStudioMessages::Engine.routes.url_helpers.message_group_path(group)
        )
      end

      def recipients_for(mount, actor)
        resolver = RecordingStudioMessages.configuration.public_contact_recipient_resolver
        return [] unless resolver.respond_to?(:call)

        Array(resolver.call(mount_recording: mount, actor: actor)).compact
      end

      def opener_among(mount, recipients)
        Array(recipients).find do |recipient|
          RecordingStudioAccessible.authorized?(actor: recipient, recording: mount, role: :admin)
        end
      end

      def grant_edit!(group, actor, manager)
        result = RecordingStudioAccessible.grant_access(
          recording: group, actor: actor, role: :edit, manager_actor: manager
        )
        return if result.success?

        raise Error, result.error.to_s
      end

      def same_actor?(left, right)
        return false if left.blank? || right.blank?

        left.instance_of?(right.class) && left.id.to_s == right.id.to_s
      end
    end
  end
end
