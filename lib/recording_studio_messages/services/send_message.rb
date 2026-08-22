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
        unless group_recordable?
          raise RecordingStudioMessages::Error, "Messages must be sent in a conversation"
        end
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
        @files.each do |file|
          result = message_recording.import_attachment(
            io: file_io(file),
            filename: file_filename(file),
            content_type: file_content_type(file),
            actor: @actor,
            name: file_name(file)
          )
          next if result.present?

          raise RecordingStudioMessages::Error, "Could not attach that file"
        end
      end

      def notify_recipients!(message_recording)
        recipients = RecordingStudioMessages.granted_actors(@group_recording).reject do |recipient|
          same_actor?(recipient, @actor)
        end
        return if recipients.empty?

        RecordingStudioNotifications.notify_each(
          recipients: recipients,
          notification_type: :message_received,
          actor: @actor,
          notifiable: message_recording.recordable,
          recording: message_recording,
          root_recording: @group_recording.root_recording,
          title: notification_title,
          body: @body.to_s.truncate(120),
          url: @url,
          metadata: {
            message_group_id: @group_recording.id,
            message_id: message_recording.id
          }
        )
      end

      def notification_title
        title = @group_recording.recordable&.title
        return "New message" if title.blank?

        "New message in #{title}"
      end

      def same_actor?(left, right)
        left.instance_of?(right.class) && left.id.to_s == right.id.to_s
      end

      def file_io(file)
        return file[:io] if file.is_a?(Hash)

        file.respond_to?(:tempfile) ? file.tempfile : file
      end

      def file_filename(file)
        return file[:filename] if file.is_a?(Hash)
        return file.original_filename if file.respond_to?(:original_filename)

        file.respond_to?(:path) ? File.basename(file.path) : "file"
      end

      def file_content_type(file)
        return file[:content_type] if file.is_a?(Hash)
        return file.content_type if file.respond_to?(:content_type)

        "application/octet-stream"
      end

      def file_name(file)
        return file[:name] if file.is_a?(Hash)

        File.basename(file_filename(file), File.extname(file_filename(file)))
      end
    end
  end
end
