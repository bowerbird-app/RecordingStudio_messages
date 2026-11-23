# frozen_string_literal: true

require_relative "target"

module RecordingStudioMessages
  module Api
    module Scope
      module_function

      def mount!(context, placement, role)
        mount = message_center!(context, placement)
        Target.authorize!(context, mount, role)
        mount
      end

      def conversation!(context, placement, role)
        group = placement.parent? ? load_group(context) : context.recording
        return actor_conversation!(context, group, role) if placement.actor_inbox?

        mount = message_center!(context, placement)
        raise ::RecordingStudioApi::NotFoundError, "Conversation not found" unless on_mount?(group, mount)

        Target.authorize!(context, group, role) if placement.parent?
        group
      end

      def actor_conversation!(context, group, role)
        raise ::RecordingStudioApi::NotFoundError, "Conversation not found" unless mine?(context, group)

        Target.authorize!(context, group, role)
        group
      end

      def mine?(context, group)
        return false unless group&.recordable_type == MESSAGE_GROUP_TYPE

        RecordingStudioMessages.my_group_recordings(actor: context.access_grant.actor).exists?(id: group.id)
      end

      def message_center!(context, placement)
        mount = placement.mount_binding.resolve(context)
        return mount if mount&.recordable_type == MESSAGE_MOUNT_TYPE

        raise ::RecordingStudioApi::NotFoundError, "Message center not found"
      end

      def load_group(context)
        id = context.params[:conversation_id].presence
        return if id.blank?

        context.access_grant.accessible_recordings.find_by(id: id)
      end

      def on_mount?(group, mount)
        group&.recordable_type == MESSAGE_GROUP_TYPE && group.parent_recording_id == mount.id
      end
    end
  end
end
