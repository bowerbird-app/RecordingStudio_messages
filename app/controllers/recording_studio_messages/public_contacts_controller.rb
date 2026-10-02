# frozen_string_literal: true

module RecordingStudioMessages
  class PublicContactsController < ActionController::Base
    include PublicContactHelper
    helper PublicContactHelper

    protect_from_forgery with: :exception
    layout "recording_studio_messages/public_contact"

    GROUP_SESSION_KEY = :recording_studio_messages_public_contact_group_id

    rescue_from ActiveRecord::RecordNotFound, with: :missing_contact
    rescue_from RecordingStudioMessages::Error, with: :contact_error

    def show
      @mount = find_mount
      return missing_contact unless @mount && RecordingStudioMessages.public_contact_enabled?(@mount)
    end

    def create
      @mount = find_mount
      return missing_contact unless @mount && RecordingStudioMessages.public_contact_enabled?(@mount)

      outcome = RecordingStudioMessages.begin_public_contact(
        mount_recording: @mount,
        name: params[:name],
        email: params[:email],
        body: params[:body],
        current_actor: public_contact_actor,
        request: request,
        session: session
      )
      if outcome.group_recording
        remember_sent(outcome.group_recording)
        redirect_to public_contact_sent_path
      else
        redirect_to public_contact_verify_path
      end
    end

    def verify
      @intent = session_intent
      return missing_contact if @intent.expired?

      if @intent.fulfilled?
        remember_sent(@intent.group_recording)
        redirect_to public_contact_sent_path
      end
    end

    def submit_verification
      @intent = session_intent
      remember_sent(PublicContact.submit_code!(intent: @intent, code: params[:code], session: session))
      redirect_to public_contact_sent_path
    end

    def sent
      return missing_contact if session[GROUP_SESSION_KEY].blank?

      @group_recording = sent_group
    end

    def resend
      @intent = session_intent
      PublicContact.resend!(intent: @intent, request: request, session: session)
      redirect_to public_contact_verify_path, notice: "Fresh code on the way."
    end

    private

    def find_mount
      return if params[:mount_id].blank?

      recording = RecordingStudio::Recording.find_by(id: params[:mount_id])
      return unless recording&.recordable_type == MESSAGE_MOUNT_TYPE

      recording
    end

    def session_intent
      PublicContactIntent.find(session[PublicContact::SESSION_KEY])
    end

    def remember_sent(group)
      session[GROUP_SESSION_KEY] = group&.id
    end

    def sent_group
      recording = RecordingStudio::Recording.find_by(id: session[GROUP_SESSION_KEY])
      return unless recording&.recordable_type == MESSAGE_GROUP_TYPE

      recording
    end

    def missing_contact(_error = nil)
      head :not_found
    end

    def contact_error(error)
      flash.now[:alert] = error.message
      template = %w[verify submit_verification resend].include?(action_name) ? :verify : :show
      render template, status: :unprocessable_entity
    end
  end
end
