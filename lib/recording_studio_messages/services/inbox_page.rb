# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class InboxPage
      ACCESS_TYPE = "RecordingStudio::Access"

      def initialize(group_recordings, actor: nil)
        @group_recordings = Array(group_recordings)
        @actor = actor
      end

      def latest_for(group_recording)
        latest_by_id[group_recording.id]
      end

      def actors_for(group_recording)
        actors_by_id[group_recording.id] || []
      end

      def ready?(group_recording)
        group_recording.recordable&.title.to_s.strip.present? &&
          latest_for(group_recording)&.recordable&.body.present?
      end

      def unread?(group_recording)
        unread_ids.include?(group_recording.id)
      end

      private

      def unread_ids
        @unread_ids ||= load_unread_ids
      end

      def latest_by_id
        @latest_by_id ||= load_latest_by_id
      end

      def actors_by_id
        @actors_by_id ||= load_actors_by_id
      end

      def group_ids
        @group_ids ||= @group_recordings.map(&:id)
      end

      def load_unread_ids
        return Set.new if @actor.blank? || group_ids.empty?

        Set.new(
          RecordingStudioMessages::Services::MessageReads.unread_ids_among(group_ids, actor: @actor)
        )
      end

      def load_latest_by_id
        return {} if group_ids.empty?

        recordings = RecordingStudio::Recording.unscoped
                                               .where(parent_recording_id: group_ids)
                                               .where(recordable_type: RecordingStudioMessages::MESSAGE_TYPE)
                                               .where(trashed_at: nil)
                                               .includes(:recordable)
                                               .order(:created_at, :id)
        recordings.to_h do |recording|
          [recording.parent_recording_id, recording]
        end
      end

      def load_actors_by_id
        return {} if group_ids.empty?
        return {} unless defined?(RecordingStudioAccessible)

        recordings = kept_recordings
                     .where(parent_recording_id: group_ids, recordable_type: ACCESS_TYPE)
                     .includes(recordable: :actor)
        recordings.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |recording, map|
          actor = recording.recordable&.actor
          map[recording.parent_recording_id] << actor if actor
        end
      end

      def kept_recordings
        scope = RecordingStudio::Recording.unscoped
        unless RecordingStudio::Recording.respond_to?(:recording_studio_trashable_kept_sql)
          return scope.where(trashed_at: nil)
        end

        scope.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
      end
    end
  end
end
