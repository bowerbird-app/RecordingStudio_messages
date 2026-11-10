# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class ListGroups
      def self.call(...)
        new(...).call
      end

      def initialize(actor:, mount_recording: nil, tags: nil, unread: false, after: nil, limit: nil)
        @actor = actor
        @mount_recording = mount_recording
        @tags = tags
        @unread = unread
        @after = after
        @limit = limit
      end

      def call
        return [] if @actor.blank?
        return [] if @mount_recording.blank?

        recordings = sort_recordings(loaded_recordings)
        recordings = page_after(recordings)
        recordings = recordings.first(@limit) if @limit.present?
        recordings
      end

      private

      def loaded_recordings
        scope = MessageGroupTags.restrict(accessible_group_recordings, @tags)
        scope = apply_unread(scope)
        scope.includes(:recordable).to_a
      end

      def apply_unread(scope)
        return scope unless @unread

        ids = scope.except(:includes).unscope(:order).pluck("recording_studio_recordings.id")
        unread_ids = MessageReads.unread_ids_among(ids, actor: @actor)
        scope.where(id: unread_ids)
      end

      def accessible_group_recordings
        RecordingStudioAccessible.recordings_for(
          actor: @actor,
          parent_recording: @mount_recording,
          minimum_role: :view,
          recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE
        )
      end

      def sort_recordings(recordings)
        recordings.sort_by do |group_recording|
          [-latest_activity_at(group_recording).to_i, group_title(group_recording)]
        end
      end

      def page_after(recordings)
        return recordings if @after.blank?

        cursor = sort_key(@after)
        recordings.select { |group_recording| (sort_key(group_recording) <=> cursor) == 1 }
      end

      def sort_key(group_recording)
        [-latest_activity_at(group_recording).to_i, group_title(group_recording)]
      end

      def latest_activity_at(group_recording)
        group_recording.recordable&.last_message_at ||
          group_recording.created_at ||
          Time.zone.at(0)
      end

      def group_title(group_recording)
        group_recording.recordable&.title.to_s
      end
    end
  end
end
