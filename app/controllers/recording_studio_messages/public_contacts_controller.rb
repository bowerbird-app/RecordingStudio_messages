# frozen_string_literal: true

module RecordingStudioMessages
  class PublicContactsController < ActionController::Base
    include PublicContactHelper
    include PublicContactFlow
    include PublicContactResponse

    helper CopyHelper
    helper PublicContactHelper
    helper PublicContactSentIconHelper
    helper PublicContactSuccessHelper

    protect_from_forgery with: :exception
    layout :public_contact_layout

    rescue_from ActiveRecord::RecordNotFound, with: :missing_contact
    rescue_from RecordingStudioMessages::Error, with: :contact_error

    def show
      @mount = enabled_mount
      return missing_contact unless @mount
      return render_code_step if resume_verification?

      render_expired_step if expired_modal_intent?
    end

    def create
      @mount = enabled_mount
      return missing_contact unless @mount

      redirect_for(start_contact)
    end

    def finish
      load_return_intent!
    end

    def complete_return
      load_return_intent!

      actor = public_contact_actor
      raise Error, Copy.t("errors.cannot_send") if actor.blank?

      remember_sent(PublicContact.complete(intent: @intent, actor: actor))
      session.delete(PublicContact::SESSION_KEY)
      redirect_to_sent
    end

    def sent
      return missing_contact if session[PublicContactFlow::GROUP_SESSION_KEY].blank?

      @group_recording = sent_group
    end
  end
end
