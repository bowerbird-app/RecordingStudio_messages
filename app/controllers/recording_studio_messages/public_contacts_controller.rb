# frozen_string_literal: true

module RecordingStudioMessages
  class PublicContactsController < ActionController::Base
    include PublicContactHelper
    include PublicContactFlow

    helper CopyHelper
    helper PublicContactHelper

    protect_from_forgery with: :exception
    layout :public_contact_layout

    rescue_from ActiveRecord::RecordNotFound, with: :missing_contact
    rescue_from RecordingStudioMessages::Error, with: :contact_error

    def show
      @mount = enabled_mount
      return missing_contact unless @mount

      render :verify if resume_verification?
    end

    def create
      @mount = enabled_mount
      return missing_contact unless @mount

      redirect_for(start_contact)
    end

    def verify
      @intent = session_intent
      return expired_contact if @intent.expired?
      return unless @intent.fulfilled?

      remember_sent(@intent.group_recording)
      redirect_to_sent
    end

    def submit_verification
      @intent = session_intent
      remember_sent(PublicContact.submit_code!(intent: @intent, code: params[:code], session: session))
      redirect_to_sent
    end

    def sent
      return missing_contact if session[PublicContactFlow::GROUP_SESSION_KEY].blank?

      @group_recording = sent_group
    end

    def resend
      @intent = session_intent
      PublicContact.resend!(intent: @intent, request: request, session: session)
      redirect_to public_contact_verify_path(presentation_params), notice: Copy.t("flashes.code_resent")
    end
  end
end
