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
          group = Target.recording(@context, MESSAGE_GROUP_TYPE)
          Target.authorize!(@context, group, :edit)
          Target.serialize(RecordingStudioMessages.send_message(**line(group)))
        end

        def line(group)
          {
            group_recording: group,
            body: @context.params[:body],
            actor: Target.actor(@context),
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
          mount = Target.recording(@context, MESSAGE_MOUNT_TYPE)
          Target.authorize!(@context, mount, :view)
          { records: groups(mount).map { |group| Target.serialize(group) } }
        end

        def groups(mount)
          RecordingStudioMessages.viewable_group_recordings(
            actor: Target.actor(@context),
            mount_recording: mount,
            tags: @context.params[:tags],
            unread: unread?,
            after: after_recording(mount),
            limit: @context.params[:limit]
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
          group = Target.recording(@context, MESSAGE_GROUP_TYPE)
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
          mount = Target.recording(@context, MESSAGE_MOUNT_TYPE)
          Target.authorize!(@context, mount, :edit)
          Target.serialize(RecordingStudioMessages.create_group(mount, **attrs))
        end

        def attrs
          {
            actor: Target.actor(@context),
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
          group = Target.recording(@context, MESSAGE_GROUP_TYPE)
          Target.authorize!(@context, group, :edit)
          Target.serialize(RecordingStudioMessages.rename_group(**attrs(group)))
        end

        def attrs(group)
          {
            group_recording: group,
            title: @context.params[:title],
            actor: Target.actor(@context)
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
          group = Target.recording(@context, MESSAGE_GROUP_TYPE)
          Target.authorize!(@context, group, :view)
          RecordingStudioMessages.mark_read(group_recording: group, actor: Target.actor(@context))
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
          { unread_count: RecordingStudioMessages.unread_count(actor: Target.actor(@context)) }
        end
      end
    end
  end
end
