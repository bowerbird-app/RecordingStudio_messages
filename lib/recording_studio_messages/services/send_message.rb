# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class SendMessage
      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, body:, actor:, files: [], url: nil, notify: true, references: [])
        @group_recording = group_recording
        @body = body.to_s
        @actor = actor
        @files = Array(files)
        @url = url
        @notify = notify
        @reference_items = Array(references)
      end

      def call
        validate!
        authorize!
        @checked_references = checked_references
        @body = MessageReferences.fallback_body(@body, @reference_items)
        validate_content!
        persist!
      end

      private

      def persist!
        SendMessagePersist.new(
          group_recording: @group_recording,
          actor: @actor,
          body: @body,
          files: @files,
          url: @url,
          notify: @notify,
          references: @checked_references
        ).call
      end

      def validate!
        raise ArgumentError, "group recording is required" if @group_recording.blank?
        raise ArgumentError, "actor is required" if @actor.blank?
        raise RecordingStudioMessages::Error, Copy.t("errors.not_a_conversation") unless group_recordable?
      end

      def validate_content!
        return if @body.present? || @files.any? || @checked_references.any?

        raise RecordingStudioMessages::Error, Copy.t("errors.write_or_attach")
      end

      def checked_references
        checker = MessageReferences.new(group_recording: @group_recording, actor: @actor)
        @reference_items.map { |item| checker.live_target!(item) }.uniq(&:id)
      end

      def authorize!
        return if RecordingStudioAccessible.authorized?(
          actor: @actor,
          recording: @group_recording,
          role: :edit
        )

        raise RecordingStudioMessages::NotAuthorized, Copy.t("errors.cannot_send_conversation")
      end

      def group_recordable?
        @group_recording.recordable_type == "RecordingStudioMessages::MessageGroup"
      end
    end
  end
end
