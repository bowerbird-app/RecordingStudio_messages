# frozen_string_literal: true

module RecordingStudioMessages
  class MessagesController < ApplicationController
    rescue_from RecordingStudioMessages::NotAuthorized, with: :handle_not_authorized
    rescue_from RecordingStudioMessages::Error, with: :handle_send_error

    def create
      @group_recording = find_group_recording
      authorize_group!(:edit)

      RecordingStudioMessages.send_message(
        group_recording: @group_recording,
        body: message_params[:body],
        actor: current_messages_actor,
        files: uploaded_files,
        url: panel_url
      )

      @message_recordings = RecordingStudioMessages.message_recordings(@group_recording)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to after_send_path, notice: "Sent." }
      end
    end

    private

    def message_params
      params.fetch(:message, {}).permit(:body, files: [])
    end

    def uploaded_files
      Array(message_params[:files]).compact_blank
    end

    def panel_url
      return_to_path.presence || message_group_path(@group_recording)
    end

    def after_send_path
      return_to_path.presence || message_group_path(@group_recording)
    end

    def return_to_path
      candidate = params[:return_to].to_s
      return if candidate.blank?
      return unless candidate.start_with?("/")
      return if candidate.start_with?("//")

      candidate
    end

    def handle_send_error(exception)
      redirect_back_or_to(panel_url, alert: exception.message)
    end
  end
end
