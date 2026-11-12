# frozen_string_literal: true

require_relative "errors"
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
          Target.authorize!(@context, group, :edit)
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
          Target.authorize!(@context, mount, :view)
          page = groups(mount)
          page_size = RecordingStudioMessages::MessageGroupsController::PAGE_SIZE
          {
            records: page.map { |group| Target.serialize(group) },
            after_id: (page.last.id if page.length >= page_size)
          }
        end

        def groups(mount)
          page_size = RecordingStudioMessages::MessageGroupsController::PAGE_SIZE
          requested = @context.params[:limit].presence
          RecordingStudioMessages.viewable_group_recordings(
            actor: @context.access_grant.actor,
            mount_recording: mount,
            tags: @context.params[:tags],
            unread: unread?,
            after: after_recording(mount),
            limit: requested ? [requested.to_i, page_size].min : page_size
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
          Target.authorize!(@context, group, :view)
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
          Target.authorize!(@context, mount, :edit)
          Target.serialize(RecordingStudioMessages.create_group(mount, **attrs))
        end

        def attrs
          {
            actor: @context.access_grant.actor,
            title: @context.params[:title],
            tags: @context.params[:tags],
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
          Target.authorize!(@context, group, :edit)
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
          Target.authorize!(@context, group, :view)
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
          Target.authorize!(@context, recording, :view)
          actor = @context.access_grant.actor
          unread = RecordingStudioMessages.my_group_recordings(actor: actor, unread: true)
          scoped = unread.merge(@context.access_grant.accessible_recordings)
          { unread_count: scoped.except(:includes).unscope(:order).count }
        end
      end
    end
  end
end
