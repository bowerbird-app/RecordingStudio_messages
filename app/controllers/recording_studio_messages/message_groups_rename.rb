# frozen_string_literal: true

module RecordingStudioMessages
  module MessageGroupsRename
    def rename
      @group_recording = find_group_recording
      authorize_rename_mount!
      raise ActiveRecord::RecordNotFound, "Conversation not found" unless rename_viewable?
      return head(:forbidden) unless rename_editable?

      apply_rename
    end

    private

    def authorize_rename_mount!
      parent = @group_recording.parent_recording
      raise ActiveRecord::RecordNotFound, "Conversation not found" unless parent&.recordable_type == MESSAGE_MOUNT_TYPE
      return if params[:mount_id].blank? || params[:mount_id].to_s == parent.id.to_s

      raise ActiveRecord::RecordNotFound, "Conversation not found"
    end

    def rename_viewable?
      RecordingStudioAccessible.authorized?(
        actor: current_messages_actor,
        recording: @group_recording,
        role: :view
      )
    end

    def rename_editable?
      RecordingStudioAccessible.authorized?(
        actor: current_messages_actor,
        recording: @group_recording,
        role: :edit
      )
    end

    def apply_rename
      RecordingStudioMessages.rename_group(
        group_recording: @group_recording,
        title: rename_title,
        actor: current_messages_actor
      )
      @group_recording.reload
      @rename_inbox = rename_inbox
      respond_after_rename
    rescue RecordingStudioMessages::Error
      head :unprocessable_entity
    end

    def respond_after_rename
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to message_group_path(@group_recording) }
      end
    end

    def rename_title
      params.dig(:message_group, :title)
    end

    def rename_inbox
      :my_messages if params[:inbox].to_s == "my_messages"
    end
  end
end
