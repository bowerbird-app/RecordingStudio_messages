# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class RenameGroup
      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, title:, actor:)
        @group_recording = group_recording
        @title = title.to_s.strip
        @actor = actor
      end

      def call
        validate!
        authorize!
        return @group_recording if current_title == @title

        revise_title
      end

      private

      def validate!
        raise ArgumentError, "group recording is required" if @group_recording.blank?
        raise ArgumentError, "actor is required" if @actor.blank?
        raise RecordingStudioMessages::Error, Copy.t("errors.not_a_conversation") unless conversation_on_mount?

        validate_title!
      end

      def validate_title!
        raise RecordingStudioMessages::Error, Copy.t("errors.enter_title") if @title.blank?
        return if @title.length <= MessageGroup::TITLE_MAX

        raise RecordingStudioMessages::Error, Copy.t("errors.title_too_long")
      end

      def conversation_on_mount?
        group_recordable? && mount_parent?
      end

      def authorize!
        return if RecordingStudioAccessible.authorized?(
          actor: @actor,
          recording: @group_recording,
          role: :edit
        )

        raise RecordingStudioMessages::NotAuthorized, Copy.t("flashes.cannot_open")
      end

      def revise_title
        root = @group_recording.root_recording || @group_recording.parent_recording
        root.revise(@group_recording, actor: @actor) do |group|
          group.title = @title
        end
      end

      def current_title
        @group_recording.recordable&.title.to_s
      end

      def group_recordable?
        @group_recording.recordable_type == MESSAGE_GROUP_TYPE
      end

      def mount_parent?
        @group_recording.parent_recording&.recordable_type == MESSAGE_MOUNT_TYPE
      end
    end
  end
end
