# frozen_string_literal: true

require_relative "errors"
require_relative "group_catalog"
require_relative "mount_catalog"
require_relative "target"

module RecordingStudioMessages
  module Api
    module Actions
      class SendMessage
        def self.call(context)
          Errors.wrap { new(context).deliver }
        end

        def initialize(context)
          @context = context
        end

        def deliver
          group = Target.accessible_recording(@context, MESSAGE_GROUP_TYPE)
          Target.authorize!(@context, group, GroupCatalog::SEND_MESSAGE.fetch(:required_role))
          Target.serialize(RecordingStudioMessages.send_message(**line(group)))
        end

        def line(group)
          {
            group_recording: group,
            body: @context.params[:body],
            actor: @context.access_grant.actor,
            references: Array(@context.params[:references])
          }
        end
      end

      class ListConversations
        def self.call(context)
          Errors.wrap { new(context).list }
        end

        def initialize(context)
          @context = context
        end

        def list
          mount = Target.accessible_recording(@context, MESSAGE_MOUNT_TYPE)
          Target.authorize!(@context, mount, MountCatalog::LIST_CONVERSATIONS.fetch(:required_role))
          page = groups(mount)
          page_size = RecordingStudioMessages::MessageGroupsController::PAGE_SIZE
          {
            records: page.map { |group| Target.serialize(group) },
            after_id: (page.last.id if page.length >= page_size)
          }
        end

        def groups(mount)
          page_size = RecordingStudioMessages::MessageGroupsController::PAGE_SIZE
          requested = @context.params[:limit]
          RecordingStudioMessages.viewable_group_recordings(
            actor: @context.access_grant.actor,
            mount_recording: mount,
            tags: Target.hash_tags(@context),
            unread: unread?,
            after: after_recording(mount),
            limit: requested.nil? || requested == "" ? page_size : requested.to_i.clamp(1, page_size)
          )
        end

        def unread?
          ActiveModel::Type::Boolean.new.cast(@context.params[:unread])
        end

        def after_recording(mount)
          raw = @context.params[:after_id].presence
          return if raw.blank?

          recording = @context.access_grant.accessible_recordings.find_by(id: raw)
          return recording if conversation_on_desk?(recording, mount)

          raise ::RecordingStudioApi::InvalidActionInputError, "after_id is not a conversation on this desk"
        end

        def conversation_on_desk?(recording, mount)
          recording&.recordable_type == MESSAGE_GROUP_TYPE &&
            recording.parent_recording_id == mount.id
        end
      end

      class ReadThread
        def self.call(context)
          Errors.wrap { new(context).read }
        end

        def initialize(context)
          @context = context
        end

        def read
          group = Target.accessible_recording(@context, MESSAGE_GROUP_TYPE)
          Target.authorize!(@context, group, GroupCatalog::READ_THREAD.fetch(:required_role))
          { records: RecordingStudioMessages.message_recordings(group).map { |row| Target.serialize(row) } }
        end
      end

      class CreateGroup
        def self.call(context)
          Errors.wrap { new(context).create }
        end

        def initialize(context)
          @context = context
        end

        def create
          mount = Target.accessible_recording(@context, MESSAGE_MOUNT_TYPE)
          Target.authorize!(@context, mount, MountCatalog::CREATE_GROUP.fetch(:required_role))
          title = @context.params[:title]
          recipients = @context.params[:recipients]
          raise ::RecordingStudioApi::InvalidActionInputError, "title is required" if title.blank? && recipients.nil?

          Target.serialize(RecordingStudioMessages.create_group(mount, **attrs))
        end

        def attrs
          {
            actor: @context.access_grant.actor,
            title: @context.params[:title],
            tags: Target.hash_tags(@context),
            recipients: @context.params[:recipients],
            body: @context.params[:body]
          }
        end
      end

      class RenameGroup
        def self.call(context)
          Errors.wrap { new(context).rename }
        end

        def initialize(context)
          @context = context
        end

        def rename
          group = Target.accessible_recording(@context, MESSAGE_GROUP_TYPE)
          Target.authorize!(@context, group, GroupCatalog::RENAME_GROUP.fetch(:required_role))
          Target.serialize(RecordingStudioMessages.rename_group(**attrs(group)))
        end

        def attrs(group)
          {
            group_recording: group,
            title: @context.params[:title],
            actor: @context.access_grant.actor
          }
        end
      end

      class MarkRead
        def self.call(context)
          Errors.wrap { new(context).mark }
        end

        def initialize(context)
          @context = context
        end

        def mark
          group = Target.accessible_recording(@context, MESSAGE_GROUP_TYPE)
          Target.authorize!(@context, group, GroupCatalog::MARK_READ.fetch(:required_role))
          RecordingStudioMessages.mark_read(group_recording: group, actor: @context.access_grant.actor)
          Target.serialize(group.reload)
        end
      end

      class UnreadCount
        def self.call(context)
          Errors.wrap { new(context).count }
        end

        def initialize(context)
          @context = context
        end

        def count
          recording = @context.access_grant.access_recording || @context.root_recording
          Target.authorize!(@context, recording, MountCatalog::UNREAD_COUNT.fetch(:required_role))
          actor = @context.access_grant.actor
          unread = RecordingStudioMessages.my_group_recordings(actor: actor, unread: true)
          scoped = unread.merge(@context.access_grant.accessible_recordings)
          { unread_count: scoped.except(:includes).unscope(:order).count }
        end
      end
    end
  end
end
