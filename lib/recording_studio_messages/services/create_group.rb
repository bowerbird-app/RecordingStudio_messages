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

        group_recording = @mount_recording.record(
          RecordingStudioMessages::MessageGroup,
          actor: @actor,
          parent_recording: @mount_recording
        ) do |group|
          group.title = @title
        end

        bootstrap_owner!(group_recording)
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

      def bootstrap_owner!(group_recording)
        return unless defined?(RecordingStudioAccessible)

        RecordingStudioAccessible.bootstrap_owner_access!(
          recording: group_recording,
          actor: @actor
        )
      end
    end
  end
end
