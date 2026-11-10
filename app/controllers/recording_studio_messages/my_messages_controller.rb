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
      RecordingStudioMessages.mark_read(group_recording: @group_recording, actor: current_messages_actor)
      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)
      respond_after_show
    end

    private

    def respond_after_show
      respond_to do |format|
        format.turbo_stream
        format.html do
          load_inbox(selected: @group_recording) unless turbo_frame_request?
          render layout: false if turbo_frame_request?
        end
      end
    end

    def load_inbox(selected: nil)
      page = inbox_page.to_a
      @unread_filter = unread_filter?
      @older_href = older_href_for(page)
      @group_recordings = page
      @inbox_page = RecordingStudioMessages::Services::InboxPage.new(page, actor: current_messages_actor)
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
        limit: PAGE_SIZE,
        unread: unread_filter?
      )
    end

    def unread_filter?
      ActiveModel::Type::Boolean.new.cast(params[:unread])
    end

    def after_recording
      raw = params[:after_id].presence
      return if raw.blank?

      recording = RecordingStudio::Recording.find_by(id: raw)
      return unless recording&.recordable_type == MESSAGE_GROUP_TYPE
      return unless inbox_member?(recording)

      recording
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def older_href_for(page)
      return if page.length < PAGE_SIZE

      query = { after_id: page.last.id }
      query[:unread] = 1 if unread_filter?
      my_messages_path(query)
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
      @inbox_page.ready?(group)
    end
  end
end
