# frozen_string_literal: true

module Staff
  class DesksController < ApplicationController
    def show
      @mount_recording = DummyCatalog.support_mount_recording
      @group_recordings = viewable_groups_on_mount
      return if @group_recordings.any?

      redirect_to root_path, alert: "You cannot open this conversation"
    end

    private

    def viewable_groups_on_mount
      RecordingStudioMessages.viewable_group_recordings(
        actor: Current.actor || current_user,
        mount_recording: @mount_recording
      )
    end
  end
end
