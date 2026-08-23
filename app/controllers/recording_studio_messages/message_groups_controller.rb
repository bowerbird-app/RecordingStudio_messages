# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupsController < ApplicationController
    rescue_from RecordingStudioMessages::NotAuthorized, with: :handle_not_authorized

    def index
      @mount_recording = find_mount_recording
      @group_recordings = viewable_groups_for_mount
      load_selected_conversation
    end

    def show
      @group_recording = find_group_recording
      authorize_group!(:view)
      @mount_recording = @group_recording.parent_recording
      @group_recordings = viewable_groups_for_mount
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    private

    def find_mount_recording
      return if params[:mount_id].blank?

      recording = RecordingStudio::Recording.find(params[:mount_id])
      return recording if recording.recordable_type == MESSAGE_MOUNT_TYPE

      raise ActiveRecord::RecordNotFound, "Desk not found"
    end

    def viewable_groups_for_mount
      RecordingStudioMessages.viewable_group_recordings(
        actor: current_messages_actor,
        mount_recording: @mount_recording
      )
    end

    def load_selected_conversation
      @group_recording = selected_group_from_params || first_ready_group
      return if @group_recording.blank?

      authorize_group!(:view)
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    def selected_group_from_params
      id = params[:id].presence
      return if id.blank?

      @group_recordings.find { |group| group.id.to_s == id.to_s }
    end

    def first_ready_group
      @group_recordings.find { |group| ready_inbox_group?(group) }
    end

    def ready_inbox_group?(group)
      group.recordable&.title.to_s.strip.present? &&
        RecordingStudioMessages.message_recordings(group).last&.recordable&.body.present?
    end
  end
end
