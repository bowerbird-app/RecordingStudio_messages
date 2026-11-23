# frozen_string_literal: true

require_relative "errors"
require_relative "scope"

module RecordingStudioMessages
  module Api
    class BoundAction
      attr_reader :placement, :action

      def initialize(handler_name, placement, action)
        @handler = Actions.const_get(handler_name)
        @placement = placement
        @action = action
      end

      def call(context)
        Errors.wrap { @handler.call(context, @placement) }
      end
    end

    module Actions
      class SendMessage
        def self.call(context, placement)
          new(context).deliver(placement)
        end

        def initialize(context)
          @context = context
        end

        def deliver(placement)
          group = Scope.conversation!(@context, placement, :edit)
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
        def self.call(context, placement)
          new(context).list(placement)
        end

        def initialize(context)
          @context = context
        end

        def list(placement)
          page = groups(placement)
          {
            records: page.map { |group| Target.serialize(group) },
            after_id: (page.last.id if page.length >= page_size)
          }
        end

        def groups(placement)
          return my_groups(**page_args(placement)) if placement.actor_inbox?

          mount_groups(placement)
        end

        def mount_groups(placement)
          RecordingStudioMessages.viewable_group_recordings(
            **page_args(placement),
            unread: unread?,
            mount_recording: Scope.mount!(@context, placement, :view)
          )
        end

        def my_groups(actor:, after:, limit:)
          RecordingStudioMessages.my_group_recordings(
            actor: actor, unread: unread?, after: after, limit: limit
          )
        end

        def page_args(placement)
          { actor: @context.access_grant.actor, after: after_recording(placement), limit: page_limit }
        end

        def page_limit
          requested = @context.params[:limit]
          requested.nil? || requested == "" ? page_size : requested.to_i.clamp(1, page_size)
        end

        def page_size
          RecordingStudioMessages::MessageGroupsController::PAGE_SIZE
        end

        def unread?
          ActiveModel::Type::Boolean.new.cast(@context.params[:unread])
        end

        def after_recording(placement)
          raw = @context.params[:after_id].presence
          return if raw.blank?

          recording = @context.access_grant.accessible_recordings.find_by(id: raw)
          return recording if listed_after?(placement, recording)

          raise ::RecordingStudioApi::InvalidActionInputError, "after_id is not a conversation on this message center"
        end

        def listed_after?(placement, recording)
          return Scope.mine?(@context, recording) if placement.actor_inbox?

          on_mount?(recording, Scope.message_center!(@context, placement))
        end

        def on_mount?(recording, mount)
          recording&.recordable_type == MESSAGE_GROUP_TYPE && recording.parent_recording_id == mount.id
        end
      end

      class ReadThread
        def self.call(context, placement)
          new(context).read(placement)
        end

        def initialize(context)
          @context = context
        end

        def read(placement)
          group = Scope.conversation!(@context, placement, :view)
          rows = RecordingStudioMessages.message_recordings(group)
          { records: rows.map { |row| Target.serialize(row) } }
        end
      end

      class CreateGroup
        def self.call(context, placement)
          new(context).create(placement)
        end

        def initialize(context)
          @context = context
        end

        def create(placement)
          mount = Scope.mount!(@context, placement, :edit)
          require_title!
          Target.serialize(RecordingStudioMessages.create_group(mount, **attrs))
        end

        def require_title!
          return if @context.params[:title].present? || !@context.params[:recipients].nil?

          raise ::RecordingStudioApi::InvalidActionInputError, "title is required"
        end

        def attrs
          {
            actor: @context.access_grant.actor,
            title: @context.params[:title],
            recipients: @context.params[:recipients],
            body: @context.params[:body]
          }
        end
      end

      class RenameGroup
        def self.call(context, placement)
          new(context).rename(placement)
        end

        def initialize(context)
          @context = context
        end

        def rename(placement)
          group = Scope.conversation!(@context, placement, :edit)
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
        def self.call(context, placement)
          new(context).mark(placement)
        end

        def initialize(context)
          @context = context
        end

        def mark(placement)
          group = Scope.conversation!(@context, placement, :view)
          RecordingStudioMessages.mark_read(group_recording: group, actor: @context.access_grant.actor)
          Target.serialize(group.reload)
        end
      end

      class UnreadCount
        def self.call(context, placement)
          new(context).count(placement)
        end

        def initialize(context)
          @context = context
        end

        def count(placement)
          actor = @context.access_grant.actor
          return { unread_count: RecordingStudioMessages.unread_count(actor: actor) } if placement.actor_inbox?

          mount = Scope.mount!(@context, placement, :view)
          groups = RecordingStudioMessages.viewable_group_recordings(
            actor: actor,
            mount_recording: mount,
            unread: true
          )
          { unread_count: groups.size }
        end
      end
    end
  end
end
