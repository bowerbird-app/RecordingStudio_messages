# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class SendMessage
      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, body:, actor:, files: [], url: nil, notify: true)
        @group_recording = group_recording
        @body = body.to_s
        @actor = actor
        @files = Array(files)
        @url = url
        @notify = notify
      end

      def call
        validate!
        authorize!

        message_recording = record_message
        attach_files!(message_recording)
        notify_recipients!(message_recording) if @notify
        message_recording
      end

      private

      def validate!
        raise ArgumentError, "group recording is required" if @group_recording.blank?
        raise ArgumentError, "actor is required" if @actor.blank?
        raise RecordingStudioMessages::Error, "Messages must be sent in a conversation" unless group_recordable?
        return if @body.present? || @files.any?

        raise RecordingStudioMessages::Error, "Write something or add a file"
      end

      def authorize!
        return if RecordingStudioAccessible.authorized?(
          actor: @actor,
          recording: @group_recording,
          role: :edit
        )

        raise RecordingStudioMessages::NotAuthorized, "You cannot send to this conversation"
      end

      def group_recordable?
        @group_recording.recordable_type == "RecordingStudioMessages::MessageGroup"
      end

      def record_message
        message = RecordingStudioMessages::Message.new(body: @body)
        RecordingStudio.record!(
          action: "created",
          recordable: message,
          root_recording: @group_recording.root_recording || @group_recording,
          parent_recording: @group_recording,
          actor: @actor
        ).recording
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

        raise RecordingStudioMessages::Error, "Could not attach that file"
      end

      def notify_recipients!(message_recording)
        NotifyGrantedActors.call(
          group_recording: @group_recording,
          message_recording: message_recording,
          actor: @actor,
          body: @body,
          url: @url
        )
      end
    end
  end
end
