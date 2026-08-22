# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class CreateGroup
      def self.call(...)
        new(...).call
      end

      def initialize(mount_recording, title:, actor:)
        @mount_recording = mount_recording
        @title = title.to_s
        @actor = actor
      end

      def call
        validate!

        group = RecordingStudioMessages::MessageGroup.new(title: @title)
        group_recording = RecordingStudio.record!(
          action: "created",
          recordable: group,
          root_recording: @mount_recording.root_recording || @mount_recording,
          parent_recording: @mount_recording,
          actor: @actor
        ).recording

        grant_owner!(group_recording)
        group_recording
      end

      private

      def validate!
        raise ArgumentError, "mount recording is required" if @mount_recording.blank?
        raise ArgumentError, "title is required" if @title.blank?
        raise ArgumentError, "actor is required" if @actor.blank?
        unless mount_recordable?
          raise RecordingStudioMessages::Error, "Groups must be created under a message mount"
        end
      end

      def mount_recordable?
        @mount_recording.recordable_type == "RecordingStudioMessages::MessageMount"
      end

      def grant_owner!(group_recording)
        return unless defined?(RecordingStudioAccessible)

        result = RecordingStudioAccessible.grant_access(
          recording: group_recording,
          actor: @actor,
          role: :admin,
          manager_actor: @actor
        )
        return if result.success?

        raise RecordingStudioMessages::Error, result.error
      end
    end
  end
end
