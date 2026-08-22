# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupsController < ApplicationController
    rescue_from RecordingStudioMessages::NotAuthorized, with: :handle_not_authorized

    def show
      @group_recording = find_group_recording
      authorize_group!(:view)
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end
  end
end
