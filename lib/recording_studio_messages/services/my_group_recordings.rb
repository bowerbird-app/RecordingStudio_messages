# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class MyGroupRecordings
      ACCESS_TYPE = "RecordingStudio::Access"
      SENTINEL = Time.utc(1970, 1, 1).freeze
      KEYSET_SQL = <<~SQL.squish.freeze
        COALESCE(recording_studio_message_groups.last_message_at, :sentinel) < :cursor_at
        OR (
          COALESCE(recording_studio_message_groups.last_message_at, :sentinel) = :cursor_at
          AND recording_studio_recordings.id < :cursor_id
        )
      SQL

      def self.call(...)
        new(...).call
      end

      def initialize(actor:, after: nil, limit: nil, unread: false)
        @actor = actor
        @after = after
        @limit = limit
        @unread = unread
      end

      def call
        return RecordingStudio::Recording.none if @actor.blank?
        return RecordingStudio::Recording.none unless defined?(RecordingStudioAccessible)
        return RecordingStudio::Recording.none unless defined?(RecordingStudio::Access)

        scope = ordered_groups.where(id: granted_group_ids)
        scope = apply_unread(scope)
        scope = apply_keyset(scope)
        scope = scope.limit(@limit) if @limit.present?
        scope.includes(:recordable, parent_recording: { parent_recording: :recordable })
      end

      def self.backfill_last_message_at!
        RecordingStudioMessages::MessageGroup.find_each do |group|
          recording = RecordingStudio::Recording.unscoped.find_by(
            recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE,
            recordable_id: group.id
          )
          latest = RecordingStudioMessages.message_recordings(recording).last
          RecordingStudioMessages::MessageGroup.unscoped.where(id: group.id).update_all(
            last_message_at: latest&.created_at
          )
        end
      end

      private

      def granted_group_ids
        RecordingStudio::Recording.unscoped
                                  .where(recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE, trashed_at: nil)
                                  .joins(access_joins)
                                  .where(recording_studio_accesses: actor_filter.merge(role: ranked_roles))
                                  .where(dependent_access_sql)
                                  .select("recording_studio_recordings.id")
      end

      def access_joins
        <<~SQL.squish
          INNER JOIN recording_studio_recordings access_recordings
            ON access_recordings.parent_recording_id = recording_studio_recordings.id
            AND access_recordings.recordable_type = #{quoted(ACCESS_TYPE)}
            AND access_recordings.trashed_at IS NULL
          INNER JOIN recording_studio_accesses
            ON recording_studio_accesses.id = access_recordings.recordable_id
        SQL
      end

      def dependent_access_sql
        <<~SQL.squish
          recording_studio_accesses.depends_on_recording_id IS NULL
          OR EXISTS (
            SELECT 1
            FROM recording_studio_recordings manager_recordings
            INNER JOIN recording_studio_accesses manager_accesses
              ON manager_accesses.id = manager_recordings.recordable_id
              AND manager_recordings.recordable_type = #{quoted(ACCESS_TYPE)}
            WHERE manager_recordings.id = recording_studio_accesses.depends_on_recording_id
              AND manager_recordings.trashed_at IS NULL
              AND manager_recordings.root_recording_id = access_recordings.root_recording_id
              AND #{ranked_role_sql('manager_accesses')}
              AND #{ranked_role_sql('recording_studio_accesses')}
              AND #{role_rank_sql('manager_accesses')} >= #{role_rank_sql('recording_studio_accesses')}
          )
        SQL
      end

      def role_rank_sql(table)
        <<~SQL.squish
          CASE #{table}.role
            WHEN 'admin' THEN 2
            WHEN 'edit' THEN 1
            WHEN 'view' THEN 0
          END
        SQL
      end

      def ranked_role_sql(table)
        "#{table}.role IN (#{ranked_roles.map { |role| quoted(role) }.join(', ')})"
      end

      def ranked_roles
        return [] unless defined?(RecordingStudio::AccessRoles)

        RecordingStudio::AccessRoles::ORDER.keys
      end

      def ordered_groups
        RecordingStudio::Recording.unscoped
                                  .select("recording_studio_recordings.*")
                                  .joins(group_join)
                                  .order(Arel.sql(order_sql))
      end

      def group_join
        <<~SQL.squish
          INNER JOIN recording_studio_message_groups
            ON recording_studio_message_groups.id = recording_studio_recordings.recordable_id
            AND recording_studio_recordings.recordable_type = #{quoted(RecordingStudioMessages::MESSAGE_GROUP_TYPE)}
        SQL
      end

      def order_sql
        <<~SQL.squish
          COALESCE(recording_studio_message_groups.last_message_at, #{quoted_time(SENTINEL)}) DESC,
          recording_studio_recordings.id DESC
        SQL
      end

      def apply_unread(scope)
        return scope unless @unread

        scope.joins(read_join).where(RecordingStudioMessages::Services::MessageReads::UNREAD_SQL)
      end

      def read_join
        <<~SQL.squish
          LEFT JOIN recording_studio_message_reads
            ON recording_studio_message_reads.message_group_recording_id = recording_studio_recordings.id
            AND recording_studio_message_reads.actor_type = #{quoted(actor_filter[:actor_type])}
            AND recording_studio_message_reads.actor_id = #{quoted(actor_filter[:actor_id])}
        SQL
      end

      def apply_keyset(scope)
        return scope if @after.blank?

        scope.where(
          KEYSET_SQL,
          sentinel: SENTINEL,
          cursor_at: sort_time(@after),
          cursor_id: @after.id
        )
      end

      def sort_time(recording)
        recording.recordable&.last_message_at || SENTINEL
      end

      def actor_filter
        {
          actor_type: RecordingStudioAccessible::ActorType.for(@actor),
          actor_id: @actor.id
        }
      end

      def quoted(value)
        RecordingStudio::Recording.connection.quote(value)
      end

      def quoted_time(time)
        RecordingStudio::Recording.connection.quote(time)
      end
    end
  end
end
