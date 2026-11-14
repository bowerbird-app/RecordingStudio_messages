# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class SendMessagePersist
      def initialize(group_recording:, actor:, body:, files:, url:, notify:, references:, preview: nil)
        @group_recording = group_recording
        @actor = actor
        @body = body
        @files = files
        @url = url
        @notify = notify
        @references = references
        @preview = preview
      end

      def call
        RecordingStudioMessages::Message.transaction { write! }
      end

      private

      def write!
        message_recording = record_message
        after_record!(message_recording)
        message_recording
      end

      def after_record!(message_recording)
        MessageReferences.attach!(
          message_recording: message_recording,
          group_recording: @group_recording,
          actor: @actor,
          references: @references
        )
        stamp_last_message_at!(message_recording)
        mark_sender_read!(message_recording)
        attach_files!(message_recording)
        notify_recipients!(message_recording) if @notify
      end

      def record_message
        RecordingStudioMessages.trusted_write(action: :send_message, mount_recording: group_mount) do
          RecordingStudio.record!(
            action: "created",
            recordable: RecordingStudioMessages::Message.new(body: @body),
            root_recording: @group_recording.root_recording || @group_recording,
            parent_recording: @group_recording,
            actor: @actor
          ).recording
        end
      end

      def stamp_last_message_at!(message_recording)
        recordable = @group_recording.recordable
        return unless recordable.respond_to?(:last_message_at)

        RecordingStudioMessages.trusted_write(action: :send_message, mount_recording: group_mount) do
          RecordingStudioMessages::MessageGroup.unscoped.where(id: recordable.id).update_all(
            last_message_at: message_recording.created_at
          )
        end
        recordable.reload
      end

      def group_mount
        @group_recording.parent_recording
      end

      def mark_sender_read!(message_recording)
        MessageReads.new(actor: @actor).upsert_cursor(
          group_recording: @group_recording,
          last_read_at: message_recording.created_at,
          last_read_message_recording_id: message_recording.id
        )
      end

      def attach_files!(message_recording)
        @files.each { |file| attach_file!(message_recording, file) }
      end

      def attach_file!(message_recording, file)
        uploaded = UploadedFile.new(file)
        result = message_recording.import_attachment(
          io: uploaded.io,
          filename: uploaded.filename,
          content_type: uploaded.content_type,
          actor: @actor,
          name: uploaded.name
        )
        return if result.present?

        raise RecordingStudioMessages::Error, Copy.t("errors.attach_failed")
      end

      def notify_recipients!(message_recording)
        NotifyGrantedActors.call(
          group_recording: @group_recording,
          message_recording: message_recording,
          actor: @actor,
          body: @preview.presence || @body,
          url: @url
        )
      end
    end
  end
end
