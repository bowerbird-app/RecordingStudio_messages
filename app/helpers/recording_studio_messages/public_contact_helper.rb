# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContactHelper
    FRAME_ID = "public_contact"
    MODAL = "modal"
    DEFAULT_TITLE = "Contact"
    DEFAULT_SUBMIT = "Send message"

    def public_contact_form(mount, title: nil, introduction: nil, submit_label: nil, heading: nil)
      render "recording_studio_messages/public_contacts/form",
             mount: mount,
             title: title.presence || DEFAULT_TITLE,
             introduction: introduction.presence || params[:introduction].presence,
             submit_label: submit_label.presence || params[:submit_label].presence || DEFAULT_SUBMIT,
             heading: heading.nil? ? show_public_contact_heading? : heading
    end

    def public_contact_modal(mount, title: nil, introduction: nil, submit_label: nil)
      render "recording_studio_messages/public_contacts/modal",
             mount: mount,
             title: title.presence || DEFAULT_TITLE,
             introduction: introduction.presence,
             submit_label: submit_label.presence || DEFAULT_SUBMIT
    end

    def public_contact_frame_id
      FRAME_ID
    end

    def modal_presentation?
      params[:presentation].to_s == MODAL
    end

    def modal_frame_request?
      modal_presentation? && request.headers["Turbo-Frame"].to_s == FRAME_ID
    end

    def public_contact_form_options
      return { data: { turbo_frame: public_contact_frame_id } } if modal_frame_request?

      { local: true, data: { turbo: false } }
    end

    def public_contact_modal_fields(introduction: params[:introduction], submit_label: params[:submit_label])
      return unless modal_presentation?

      safe_join([
        hidden_field_tag(:presentation, MODAL),
        hidden_introduction(introduction),
        hidden_submit_label(submit_label)
      ].compact)
    end

    def public_contact_restart_path(mount_id)
      contact_routes.public_contact_path(
        { mount_id: mount_id, presentation: MODAL }.merge(
          modal_display_params(params[:introduction], params[:submit_label])
        )
      )
    end

    def public_contact_modal_src(mount, introduction:, submit_label:)
      contact_routes.public_contact_path(
        { mount_id: mount.id, presentation: MODAL }.merge(modal_display_params(introduction, submit_label))
      )
    end

    def public_contact_actor
      warden = request.env["warden"]
      return unless warden.respond_to?(:authenticated?)
      return unless warden.authenticated?(:user)

      warden.user(:user)
    end

    def public_contact_sent_icon
      RecordingStudioMessages.configuration.public_contact_sent_icon.presence
    end

    def public_contact_submit_path(mount)
      contact_routes.public_contact_path(mount_id: mount.id)
    end

    def public_contact_typed(key)
      params[key].presence
    end

    def public_contact_input(key, **options)
      typed = public_contact_typed(key)
      options[:value] = typed if typed
      options
    end

    private

    def contact_routes
      respond_to?(:public_contact_path) ? self : recording_studio_messages
    end

    def show_public_contact_heading?
      !modal_frame_request?
    end

    def modal_display_params(introduction, submit_label)
      label = submit_label.presence
      label = nil if label == DEFAULT_SUBMIT
      { introduction: introduction.presence, submit_label: label }.compact
    end

    def hidden_introduction(introduction)
      return if introduction.blank?

      hidden_field_tag(:introduction, introduction)
    end

    def hidden_submit_label(submit_label)
      return if submit_label.blank? || submit_label == DEFAULT_SUBMIT

      hidden_field_tag(:submit_label, submit_label)
    end
  end
end
