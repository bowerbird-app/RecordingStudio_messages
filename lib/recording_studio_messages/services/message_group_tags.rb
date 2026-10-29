# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    module MessageGroupTags
      module_function

      def tag(group_recording, key:, recording:)
        upsert_tag(
          group_recording_id!(group_recording),
          normalize_key!(key),
          tagged_recording_id!(recording)
        )
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      def untag(group_recording, key:, recording: nil)
        scope = RecordingStudioMessages::MessageGroupTag.where(
          message_group_recording_id: group_recording_id!(group_recording),
          key: normalize_key!(key)
        )
        scope = scope.where(tagged_recording_id: tagged_recording_id!(recording)) if recording
        scope.delete_all
      end

      def restrict(scope, tags)
        required = normalize_tags(tags)
        return scope if required.empty?

        required.reduce(scope) do |filtered, (tag_key, tagged_id)|
          matching_ids = RecordingStudioMessages::MessageGroupTag.where(
            key: tag_key,
            tagged_recording_id: tagged_id
          ).select(:message_group_recording_id)
          filtered.where(id: matching_ids)
        end
      end

      def upsert_tag(group_id, tag_key, tagged_id)
        row = RecordingStudioMessages::MessageGroupTag.find_or_initialize_by(
          message_group_recording_id: group_id,
          key: tag_key
        )
        row.tagged_recording_id = tagged_id
        row.save!
        row
      end

      def normalize_tags(tags)
        return [] if tags.blank?

        tags.map do |tag_key, recording|
          [normalize_key!(tag_key), tagged_recording_id!(recording)]
        end
      end

      def group_recording_id!(group_recording)
        raise ArgumentError, "group recording is required" if group_recording.blank?
        unless group_recording.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE
          raise RecordingStudioMessages::Error, "Tags belong on a conversation"
        end

        group_recording.id
      end

      def tagged_recording_id!(recording)
        raise ArgumentError, "tagged recording is required" if recording.blank?
        return recording.id if recording.is_a?(RecordingStudio::Recording)

        raise ArgumentError, "tagged recording must be a Recording"
      end

      def normalize_key!(key)
        tag_key = key.to_s.strip
        raise ArgumentError, "tag key is required" if tag_key.blank?

        tag_key
      end
    end
  end
end
