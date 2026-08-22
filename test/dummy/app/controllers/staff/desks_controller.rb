# frozen_string_literal: true

module Staff
  class DesksController < ApplicationController
    def show
      @group_recording = DummyCatalog.support_group_recording
      unless RecordingStudioAccessible.authorized?(actor: Current.actor, recording: @group_recording, role: :view)
        redirect_to root_path, alert: "You cannot open this conversation" and return
      end

      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end
  end
end
