# frozen_string_literal: true

module Customer
  class InboxesController < ApplicationController
    def show
      @mount_recording = DummyCatalog.inbox_mount_recording
      @group_recordings = viewable_groups_on_mount
      return redirect_to root_path, alert: "You cannot open this conversation" if @group_recordings.blank?

      load_selected_conversation
    end

    private

    def viewable_groups_on_mount
      RecordingStudioMessages.viewable_group_recordings(
        actor: Current.actor || current_user,
        mount_recording: @mount_recording
      )
    end

    def load_selected_conversation
      @group_recording = selected_group_from_params || first_ready_group
      return if @group_recording.blank?

      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    def selected_group_from_params
      id = params[:group_id].presence
      return if id.blank?

      @group_recordings.find { |group| group.id.to_s == id.to_s }
    end

    def first_ready_group
      @group_recordings.find do |group|
        group.recordable&.title.to_s.strip.present? &&
          RecordingStudioMessages.message_recordings(group).last&.recordable&.body.present?
      end
    end
  end
end
