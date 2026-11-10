# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class MessageReferences
      def self.attach!(message_recording:, group_recording:, actor:, references:)
        new(group_recording: group_recording, actor: actor).attach!(message_recording, references)
      end

      def self.visible_for(message_recordings, actor:)
        VisibleMessageReferences.call(message_recordings, actor: actor)
      end

      def self.fallback_body(body, references)
        MessageReferenceFallback.apply(body, references)
      end

      def initialize(actor:, group_recording: nil)
        @actor = actor
        @group_recording = group_recording
      end

      def attach!(message_recording, references)
        Array(references).map { |item| live_target!(item) }.uniq(&:id).each do |target|
          MessageReference.create!(
            message_recording_id: message_recording.id,
            target_recording_id: target.id
          )
        end
      end

      def live_target!(item)
        recording = locate(item)
        raise RecordingStudioMessages::Error, Copy.t("errors.cannot_attach_item") unless attachable?(recording)

        recording
      end

      private

      def attachable?(recording)
        recording.present? &&
          recording.trashed_at.blank? &&
          viewer_can_see?(recording) &&
          under_mount?(recording)
      end

      def locate(item)
        id = recording_id_for(item)
        return if id.blank?

        RecordingStudio::Recording.unscoped.find_by(id: id)
      end

      def recording_id_for(item)
        return item.id if item.respond_to?(:id) && item.respond_to?(:recordable_type)
        return item[:recording_id].presence || item["recording_id"] if item.is_a?(Hash)

        item
      end

      def viewer_can_see?(recording)
        RecordingStudioAccessible.authorized?(actor: @actor, recording: recording, role: :view)
      end

      def under_mount?(recording)
        ancestor = mount_parent
        ancestor.present? && RecordingSubtree.under_parent?([recording], ancestor)
      end

      def mount_parent
        mount = @group_recording&.parent_recording
        return if mount.blank?
        return unless mount.recordable_type == RecordingStudioMessages::MESSAGE_MOUNT_TYPE

        mount.parent_recording
      end
    end
  end
end
