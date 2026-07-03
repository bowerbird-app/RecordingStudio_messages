# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupsController < ApplicationController
    before_action :require_create_group_authorization!, only: %i[new create]

    def index
      @paginator = MessageGroupPaginator.new(
        messages_config: messages_config,
        actor: current_actor_record,
        container_recording: container_recording,
        page: params[:page]
      )
      @message_group_recordings = @paginator.page_records
      @can_create_group = create_group_authorized?
    end

    def new; end

    def create
      result = MessageGroupCreator.new(
        messages_config: messages_config,
        actor: current_actor_record,
        container_recording: container_recording,
        params: group_params.to_h,
        controller: self
      ).create!
      redirect_to message_group_path(messages_config.key, result.message_group_recording, container_recording_id: container_recording.id)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      @error = e.message
      render :new, status: :unprocessable_entity
    end

    def show
      @message_group_recording = find_visible_message_group!
      @paginator = MessageHistoryPaginator.new(message_group_recording: @message_group_recording, page: params[:page])
      @message_recordings = @paginator.page_records
      @can_post = RecordingStudioAccessible.authorized?(actor: current_actor_record, recording: @message_group_recording, role: :edit)
    end

    def history
      @message_group_recording = find_visible_message_group!
      @paginator = MessageHistoryPaginator.new(message_group_recording: @message_group_recording, page: params[:page])
      @message_recordings = @paginator.page_records
      render partial: "recording_studio_messages/messages/message", collection: @message_recordings, as: :message_recording
    end

    private

    def find_visible_message_group!
      find_message_group_recording!(params[:id], role: :view)
    end

    def group_params
      params.fetch(:message_group, {}).permit(
        :title,
        :subject,
        :body,
        recipients: %i[recipient_type recipient_id],
        content: {},
        metadata: {},
        group_metadata: {}
      )
    end
  end
end
