# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContactTagHelper
    def contact_tag_token(mount, tags)
      return PublicContact::TagToken.generate(mount: mount, tags: tags) if tags.present?

      params[PublicContact::TagToken::PARAM].presence
    end

    def tag_token_query(token = params[PublicContact::TagToken::PARAM])
      value = token.presence
      value ? { PublicContact::TagToken::PARAM => value } : {}
    end

    def public_contact_restart_path(mount_id)
      contact_routes.public_contact_path(
        { mount_id: mount_id, presentation: PublicContactHelper::MODAL }.merge(
          modal_display_params(params[:introduction], params[:submit_label])
        ).merge(tag_token_query)
      )
    end

    def public_contact_modal_src(mount, introduction:, submit_label:, tags: nil, tag_token: nil)
      token = tag_token.presence || contact_tag_token(mount, tags)
      contact_routes.public_contact_path(
        { mount_id: mount.id, presentation: PublicContactHelper::MODAL }.merge(
          modal_display_params(introduction, submit_label)
        ).merge(tag_token_query(token))
      )
    end
  end
end
