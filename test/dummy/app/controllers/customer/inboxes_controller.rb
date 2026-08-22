# frozen_string_literal: true

module Customer
  class InboxesController < ApplicationController
    def show
      @group_recording = DummyCatalog.inbox_group_recording
      actor = Current.actor || current_user
      unless actor && RecordingStudioAccessible.authorized?(actor: actor, recording: @group_recording, role: :view)
        redirect_to root_path, alert: "You cannot open this conversation" and return
      end

      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end
  end
end
