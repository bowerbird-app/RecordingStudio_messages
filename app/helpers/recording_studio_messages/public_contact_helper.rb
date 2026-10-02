# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContactHelper
    def public_contact_form(mount, title: nil, introduction: nil, submit_label: nil)
      render "recording_studio_messages/public_contacts/form",
             mount: mount,
             title: title.presence || "Contact",
             introduction: introduction.presence,
             submit_label: submit_label.presence || "Send message"
    end

    def public_contact_actor
      warden = request.env["warden"]
      return unless warden.respond_to?(:authenticated?)
      return unless warden.authenticated?(:user)

      warden.user(:user)
    end

    def public_contact_submit_path(mount)
      routes = respond_to?(:public_contact_path) ? self : recording_studio_messages
      routes.public_contact_path(mount_id: mount.id)
    end
  end
end
