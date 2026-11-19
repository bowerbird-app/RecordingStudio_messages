# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class InboxCard
      PREVIEW_LIMIT = 3

      def self.build(actor:, title:, mine: false, mount: nil, limit: PREVIEW_LIMIT)
        new(actor:, title:, mine:, mount:, limit:)
      end

      def initialize(actor:, title:, mine:, mount:, limit:)
        @actor = actor
        @title = title.to_s.strip
        @mine = mine == true
        @mount = mount
        @limit = Integer(limit)
        validate!
        @visible = any_conversations?
        @groups = @visible ? preview_groups : []
        @unread_count = @visible ? count_unread : 0
      end

      attr_reader :actor, :title, :mount, :groups, :unread_count, :limit

      def mine?
        @mine
      end

      def visible?
        @visible
      end

      def row_inbox
        return :my_messages if mine?

        nil
      end

      private

      def validate!
        raise ArgumentError, "pass a title" if @title.blank?
        raise ArgumentError, "limit must be at least 1" if @limit < 1
        return if @mine ^ @mount.present?

        raise ArgumentError, "pass mine: true or mount:"
      end

      def any_conversations?
        return false if @actor.blank?
        return mine_scope.exists? if mine?

        mount_scope.exists?
      end

      def preview_groups
        if mine?
          RecordingStudioMessages.my_group_recordings(actor: @actor, limit: @limit).to_a
        else
          RecordingStudioMessages.viewable_group_recordings(
            actor: @actor,
            mount_recording: @mount,
            limit: @limit
          )
        end
      end

      def count_unread
        return RecordingStudioMessages.unread_count(actor: @actor) if mine?

        RecordingStudioMessages.viewable_group_recordings(
          actor: @actor,
          mount_recording: @mount,
          unread: true
        ).size
      end

      def mine_scope
        RecordingStudioMessages.my_group_recordings(actor: @actor)
      end

      def mount_scope
        return RecordingStudio::Recording.none if @mount.blank?
        return RecordingStudio::Recording.none unless defined?(RecordingStudioAccessible)

        RecordingStudioAccessible.recordings_for(
          actor: @actor,
          parent_recording: @mount,
          minimum_role: :view,
          recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE
        )
      end
    end
  end
end
