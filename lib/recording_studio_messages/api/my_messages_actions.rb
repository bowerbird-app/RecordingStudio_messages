# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Actions
      module MyMessages
        def actor
          @context.access_grant.actor
        end

        def conversation!(role)
          group = @context.recording
          unless group&.recordable_type == MESSAGE_GROUP_TYPE
            raise ::RecordingStudioApi::NotFoundError, "Conversation not found"
          end

          Target.authorize!(@context, group, role)
          group
        end

        def unread_only?
          ActiveModel::Type::Boolean.new.cast(@context.params[:unread])
        end
      end

      class ListMyMessages
        include MyMessages

        def self.call(context, _placement)
          new(context).list
        end

        def initialize(context)
          @context = context
        end

        def list
          page = groups.to_a
          {
            records: page.map { |group| Target.serialize(group) },
            after_id: (page.last.id if page.length >= page_limit)
          }
        end

        def groups
          RecordingStudioMessages.my_group_recordings(
            actor: actor,
            unread: unread_only?,
            after: after_recording,
            limit: page_limit
          )
        end

        def page_limit
          requested = @context.params[:limit]
          return page_size if requested.nil? || requested == ""

          requested.to_i.clamp(1, page_size)
        end

        def page_size
          RecordingStudioMessages::MyMessagesController::PAGE_SIZE
        end

        def after_recording
          raw = @context.params[:after_id].presence
          return if raw.blank?

          recording = RecordingStudio::Recording.find_by(id: raw)
          return recording if inbox_member?(recording)

          raise ::RecordingStudioApi::InvalidActionInputError, "after_id is not a conversation in My Messages"
        end

        def inbox_member?(recording)
          return false unless recording&.recordable_type == MESSAGE_GROUP_TYPE

          RecordingStudioMessages.my_group_recordings(actor: actor).exists?(id: recording.id)
        end
      end

      class ReadMyMessages
        include MyMessages

        def self.call(context, _placement)
          new(context).read
        end

        def initialize(context)
          @context = context
        end

        def read
          group = conversation!(:view)
          rows = RecordingStudioMessages.message_recordings(group)
          { records: rows.map { |row| Target.serialize(row) } }
        end
      end

      class SendMyMessage
        include MyMessages

        def self.call(context, _placement)
          new(context).deliver
        end

        def initialize(context)
          @context = context
        end

        def deliver
          group = conversation!(:edit)
          Target.serialize(RecordingStudioMessages.send_message(**line(group)))
        end

        def line(group)
          {
            group_recording: group,
            body: @context.params[:body],
            actor: actor,
            references: Array(@context.params[:references])
          }
        end
      end

      class MarkMyMessageRead
        include MyMessages

        def self.call(context, _placement)
          new(context).mark
        end

        def initialize(context)
          @context = context
        end

        def mark
          group = conversation!(:view)
          RecordingStudioMessages.mark_read(group_recording: group, actor: actor)
          Target.serialize(group.reload)
        end
      end

      class CountUnreadMyMessages
        include MyMessages

        def self.call(context, _placement)
          new(context).count
        end

        def initialize(context)
          @context = context
        end

        def count
          { unread_count: RecordingStudioMessages.unread_count(actor: actor) }
        end
      end
    end
  end
end
