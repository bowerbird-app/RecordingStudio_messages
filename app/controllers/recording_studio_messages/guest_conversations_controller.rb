# frozen_string_literal: true

module RecordingStudioMessages
  class GuestConversationsController < ApplicationController
    rescue_from RecordingStudioMessages::NotAuthorized, with: :handle_not_authorized

    def show
      @group_recording = find_group_recording
      authorize_group!(:view)
      RecordingStudioMessages.mark_read(group_recording: @group_recording, actor: current_messages_actor)
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end
  end
end
