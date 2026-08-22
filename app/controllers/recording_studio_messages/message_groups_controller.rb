# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupsController < ApplicationController
    rescue_from RecordingStudioMessages::NotAuthorized, with: :handle_not_authorized

    def index
      @mount_recording = find_mount_recording
      @group_recordings = viewable_groups_for_index
    end

    def show
      @group_recording = find_group_recording
      authorize_group!(:view)
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    private

    def find_mount_recording
      return if params[:mount_id].blank?

      recording = RecordingStudio::Recording.find(params[:mount_id])
      return recording if recording.recordable_type == MESSAGE_MOUNT_TYPE

      raise ActiveRecord::RecordNotFound, "Desk not found"
    end

    def viewable_groups_for_index
      RecordingStudioMessages.viewable_group_recordings(
        actor: current_messages_actor,
        mount_recording: @mount_recording
      )
    end
  end
end
