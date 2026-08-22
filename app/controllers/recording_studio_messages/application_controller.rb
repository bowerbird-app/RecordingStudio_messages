# frozen_string_literal: true

module RecordingStudioMessages
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout
    helper RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)
    helper RecordingStudioMessages::PanelHelper

    helper_method :current_messages_actor

    private

    def current_messages_actor
      return Current.actor if defined?(Current) && Current.respond_to?(:actor) && Current.actor.present?
      return current_user if respond_to?(:current_user, true)

      nil
    end

    def find_group_recording(id = params[:message_group_id] || params[:id])
      recording = RecordingStudio::Recording.find(id)
      unless recording.recordable_type == MESSAGE_GROUP_TYPE
        raise ActiveRecord::RecordNotFound, "Conversation not found"
      end

      recording
    end

    def authorize_group!(role, recording = @group_recording)
      return if RecordingStudioAccessible.authorized?(
        actor: current_messages_actor,
        recording: recording,
        role: role
      )

      raise RecordingStudioMessages::NotAuthorized, "You cannot open this conversation"
    end

    def handle_not_authorized
      redirect_back_or_to(main_app.root_path, alert: "You cannot open this conversation")
    end
  end
end
