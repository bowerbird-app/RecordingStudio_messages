# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class ListGroups
      def self.call(...)
        new(...).call
      end

      def initialize(actor:, mount_recording: nil, tags: nil)
        @actor = actor
        @mount_recording = mount_recording
        @tags = tags
      end

      def call
        return [] if @actor.blank?
        return [] if @mount_recording.blank?

        viewable_recordings.sort_by do |group_recording|
          [-latest_activity_at(group_recording).to_i, group_title(group_recording)]
        end
      end

      private

      def viewable_recordings
        MessageGroupTags.restrict(accessible_group_recordings, @tags)
      end

      def accessible_group_recordings
        RecordingStudioAccessible.recordings_for(
          actor: @actor,
          parent_recording: @mount_recording,
          minimum_role: :view,
          recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE
        ).includes(:recordable)
      end

      def latest_activity_at(group_recording)
        latest = RecordingStudioMessages.message_recordings(group_recording).last
        latest&.created_at || group_recording.created_at || Time.zone.at(0)
      end

      def group_title(group_recording)
        group_recording.recordable&.title.to_s
      end
    end
  end
end
