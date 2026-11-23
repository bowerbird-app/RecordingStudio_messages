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
        mount = message_center!(context, placement)
        group = group_on_mount(context, placement, mount)
        Target.authorize!(context, group, role) if placement.parent?
        group
      end

      def message_center!(context, placement)
        mount = placement.mount_binding.resolve(context)
        return mount if mount&.recordable_type == MESSAGE_MOUNT_TYPE

        raise ::RecordingStudioApi::NotFoundError, "Message center not found"
      end

      def group_on_mount(context, placement, mount)
        group = placement.parent? ? load_group(context) : context.recording
        return group if on_mount?(group, mount)

        raise ::RecordingStudioApi::NotFoundError, "Conversation not found"
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
