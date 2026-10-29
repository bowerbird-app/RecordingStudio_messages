# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class CreateGroup
      def self.call(...)
        new(...).call
      end

      def initialize(mount_recording, title:, actor:, tags: nil)
        @mount_recording = mount_recording
        @title = title.to_s
        @actor = actor
        @tags = tags
      end

      def call
        validate!
        checked = MessageGroupTags.normalize_tags(@tags)
        RecordingStudio::Recording.transaction do
          group_recording = record_group
          grant_owner!(group_recording)
          write_tags(group_recording, checked)
          group_recording
        end
      end

      private

      def write_tags(group_recording, checked)
        checked.each do |key, recording|
          MessageGroupTags.tag(group_recording, key: key, recording: recording)
        end
      end

      def record_group
        group = RecordingStudioMessages::MessageGroup.new(title: @title)
        RecordingStudio.record!(
          action: "created",
          recordable: group,
          root_recording: @mount_recording.root_recording || @mount_recording,
          parent_recording: @mount_recording,
          actor: @actor
        ).recording
      end

      def validate!
        raise ArgumentError, "mount recording is required" if @mount_recording.blank?
        raise ArgumentError, "title is required" if @title.blank?
        raise ArgumentError, "actor is required" if @actor.blank?
        return if mount_recordable?

        raise RecordingStudioMessages::Error, "Groups must be created under a message mount"
      end

      def mount_recordable?
        @mount_recording.recordable_type == "RecordingStudioMessages::MessageMount"
      end

      def grant_owner!(group_recording)
        return unless defined?(RecordingStudioAccessible)

        result = owner_grant_result(group_recording)
        return if result.success?

        raise RecordingStudioMessages::Error, result.error
      end

      def owner_grant_result(group_recording)
        RecordingStudioMessages.allow_membership_change do
          RecordingStudioAccessible.grant_access(
            recording: group_recording,
            actor: @actor,
            role: :admin,
            manager_actor: @actor
          )
        end
      end
    end
  end
end
