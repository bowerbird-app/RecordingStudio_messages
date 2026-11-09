# frozen_string_literal: true

module RecordingStudioMessages
  class MyMessagesController < ApplicationController
    PAGE_SIZE = 50

    rescue_from RecordingStudioMessages::NotAuthorized, with: :handle_not_authorized

    def index
      load_inbox
    end

    def show
      @group_recording = find_group_recording
      authorize_group!(:view)
      load_inbox(selected: @group_recording)
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
      render layout: false if turbo_frame_request?
    end

    private

    def load_inbox(selected: nil)
      page = inbox_page.to_a
      @older_href = older_href_for(page)
      @group_recordings = page
      @group_recording = selected || selected_group_from_params || first_ready_group
      return if @group_recording.blank?

      authorize_group!(:view)
      prepend_selected_row
      assign_thread_messages
    end

    def assign_thread_messages
      return if defined?(@message_recordings) && @message_recordings

      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
    end

    def inbox_page
      RecordingStudioMessages.my_group_recordings(
        actor: current_messages_actor,
        after: after_recording,
        limit: PAGE_SIZE
      )
    end

    def after_recording
      return if params[:after_id].blank?

      RecordingStudio::Recording.find_by(id: params[:after_id])
    end

    def older_href_for(page)
      return if page.length < PAGE_SIZE

      my_messages_path(after_id: page.last.id)
    end

    def selected_group_from_params
      id = params[:id].presence
      return if id.blank?

      @group_recordings.find { |group| group.id.to_s == id.to_s }
    end

    def prepend_selected_row
      return if @group_recording.blank?
      return if @group_recordings.any? { |group| group.id.to_s == @group_recording.id.to_s }
      return unless inbox_member?(@group_recording)

      @group_recordings = [@group_recording] + @group_recordings
    end

    def inbox_member?(recording)
      RecordingStudioMessages.my_group_recordings(actor: current_messages_actor).exists?(id: recording.id)
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
