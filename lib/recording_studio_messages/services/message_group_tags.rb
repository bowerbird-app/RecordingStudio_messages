# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    module MessageGroupTags
      module_function

      def tag(group_recording, key:, recording:)
        upsert_tag(
          group_recording_id!(group_recording),
          normalize_key!(key),
          live_tagged_recording!(recording).id
        )
      end

      def untag(group_recording, key:, recording: nil)
        scope = RecordingStudioMessages::MessageGroupTag.where(
          message_group_recording_id: group_recording_id!(group_recording),
          key: normalize_key!(key)
        )
        scope = scope.where(tagged_recording_id: tagged_recording!(recording).id) if recording
        scope.delete_all
      end

      def recordings_for_mount(mount_recording, tags)
        raise ArgumentError, "mount recording is required" if mount_recording.blank?
        unless mount_recording.recordable_type == RecordingStudioMessages::MESSAGE_MOUNT_TYPE
          raise RecordingStudioMessages::Error, "mount recording must be a message mount"
        end

        restrict(kept_groups(mount_recording), tags)
      end

      def restrict(scope, tags)
        required = normalize_tags(tags, live: false)
        return scope if required.empty?

        required.reduce(scope) do |filtered, (tag_key, recording)|
          matching_ids = RecordingStudioMessages::MessageGroupTag.where(
            key: tag_key,
            tagged_recording_id: recording.id
          ).select(:message_group_recording_id)
          filtered.where(id: matching_ids)
        end
      end

      def upsert_tag(group_id, tag_key, tagged_id)
        RecordingStudioMessages::MessageGroupTag.upsert(
          {
            message_group_recording_id: group_id, key: tag_key,
            tagged_recording_id: tagged_id, created_at: Time.current
          },
          unique_by: :index_message_group_tags_on_group_and_key,
          update_only: %i[tagged_recording_id],
          record_timestamps: false
        )
        RecordingStudioMessages::MessageGroupTag.find_by!(message_group_recording_id: group_id, key: tag_key)
      end

      def normalize_tags(tags, live: true)
        return {} if tags.blank?
        raise ArgumentError, "tags must be a Hash" unless tags.is_a?(Hash)

        tags.each_with_object({}) do |(key, recording), normalized|
          checked = live ? live_tagged_recording!(recording) : tagged_recording!(recording)
          assign_normalized_tag!(normalized, key, checked)
        end
      end

      def tag_ids(tags)
        normalize_tags(tags).transform_values { |recording| recording.id.to_s }
      end

      def tags_from_ids(stored)
        return {} if stored.blank?
        raise ArgumentError, "tags must be a Hash" unless stored.is_a?(Hash)

        found = RecordingStudio::Recording.unscoped.kept.where(id: stored.values).index_by do |recording|
          recording.id.to_s
        end
        stored.each_with_object({}) do |(key, id), loaded|
          recording = found.fetch(id.to_s) { raise ArgumentError, "tagged recording is missing" }
          assign_normalized_tag!(loaded, key, recording)
        end
      end

      def group_recording_id!(group_recording)
        raise ArgumentError, "group recording is required" if group_recording.blank?
        unless group_recording.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE
          raise RecordingStudioMessages::Error, "Tags belong on a conversation"
        end

        group_recording.id
      end

      def tagged_recording!(recording)
        raise ArgumentError, "tagged recording is required" if recording.blank?
        raise ArgumentError, "tagged recording must be a Recording" unless recording.is_a?(RecordingStudio::Recording)
        raise ArgumentError, "tagged recording must be saved" if recording.id.blank?

        recording
      end

      def live_tagged_recording!(recording)
        LiveRecording.find(tagged_recording!(recording).id) || raise(ArgumentError, "tagged recording is missing")
      end

      def assign_normalized_tag!(normalized, key, recording)
        tag_key = normalize_key!(key)
        previous = normalized[tag_key]
        raise ArgumentError, "tag key is repeated" if previous && previous.id != recording.id

        normalized[tag_key] = recording
      end

      def kept_groups(mount_recording)
        RecordingStudio::Recording.unscoped.kept.where(
          parent_recording_id: mount_recording.id,
          recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE
        )
      end

      def normalize_key!(key)
        key.to_s.strip.tap { |tag_key| raise ArgumentError, "tag key is required" if tag_key.blank? }
      end

      private_class_method :assign_normalized_tag!, :kept_groups, :tagged_recording!, :live_tagged_recording!
    end
  end
end
