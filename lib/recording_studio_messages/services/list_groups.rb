# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class ListGroups
      def self.call(...)
        new(...).call
      end

      def initialize(actor:, mount_recording: nil)
        @actor = actor
        @mount_recording = mount_recording
      end

      def call
        return [] if @actor.blank?

        candidates.select { |group_recording| viewable?(group_recording) }.sort_by do |group_recording|
          [-latest_activity_at(group_recording).to_i, group_title(group_recording)]
        end
      end

      private

      def candidates
        scope = RecordingStudio::Recording.unscoped.where(
          recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE,
          trashed_at: nil
        ).includes(:recordable)
        return scope if @mount_recording.blank?

        scope.where(parent_recording_id: @mount_recording.id)
      end

      def viewable?(group_recording)
        RecordingStudioAccessible.authorized?(
          actor: @actor,
          recording: group_recording,
          role: :view
        )
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
