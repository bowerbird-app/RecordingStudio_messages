# frozen_string_literal: true

module RecordingStudioMessages
  # Redirects and the return step for public contact.
  module PublicContactResponse
    private

    def redirect_for(outcome)
      if outcome.group_recording
        remember_sent(outcome.group_recording)
        redirect_to_sent
      elsif modal_presentation?
        redirect_to public_contact_path(presentation_params.merge(mount_id: @mount.id))
      else
        prepare_code_step(outcome.intent)
        redirect_to otp_challenge_url
      end
    end

    def render_code_step
      prepare_code_step(@intent)
      render :code
    end

    def render_expired_step
      render :expired, status: :unprocessable_entity
    end

    def prepare_code_step(intent)
      @intent = intent
      @contact_token = PublicContact::ReturnToken.generate(intent)
      RecordingStudioUser::ReturnTo.remember(session, return_path_for(@contact_token))
    end

    def return_path_for(token)
      public_contact_return_path(PublicContact::ReturnToken::PARAM => token)
    end

    def otp_challenge_url
      main_app.recording_studio_user_otp_challenge_path(script_name: "")
    end

    def redirect_to_sent
      redirect_to public_contact_sent_path(sent_presentation_params)
    end

    def sent_presentation_params
      presentation_params.except(PublicContact::TagToken::PARAM, PublicContact::TagToken::PARAM.to_s)
    end

    def presentation_params
      extra = tag_token_query
      return extra unless modal_presentation?

      { presentation: PublicContactHelper::MODAL }.merge(
        modal_display_params(params[:introduction], params[:submit_label])
      ).merge(extra)
    end

    def load_return_intent!
      @contact_token = params[PublicContact::ReturnToken::PARAM].to_s
      @intent = PublicContact::ReturnToken.intent_for(@contact_token)
      raise Error, Copy.t("errors.return_denied") if @intent.nil?

      @mount = RecordingStudio::Recording.unscoped.find_by(id: @intent.mount_recording_id)
    end

    def contact_error(error)
      return render_expired_contact if modal_frame_request? && @intent&.expired?

      flash.now[:alert] = error.message
      render(@mount.present? ? error_template : :denied, status: :unprocessable_entity)
    end

    def render_expired_contact
      render :expired, status: :unprocessable_entity
    end

    def error_template
      :show
    end
  end
end
