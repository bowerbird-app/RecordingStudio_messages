# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class MessageReads
      ACCESS_TYPE = "RecordingStudio::Access"
      UNIQUE_BY = :index_message_reads_on_actor_and_group
      BACKFILL_BATCH = 500
      UNREAD_SQL = <<~SQL.squish.freeze
        recording_studio_message_groups.last_message_at IS NOT NULL
        AND (
          recording_studio_message_reads.id IS NULL
          OR recording_studio_message_groups.last_message_at > recording_studio_message_reads.last_read_at
        )
      SQL

      def self.mark_read(group_recording:, actor:)
        new(actor: actor).mark_read(group_recording)
      end

      def self.unread?(group_recording:, actor:)
        new(actor: actor).unread?(group_recording)
      end

      def self.unread_count(actor:)
        new(actor: actor).unread_count
      end

      def self.unread_ids_among(group_ids, actor:)
        new(actor: actor).unread_ids_among(group_ids)
      end

      def self.backfill_existing_as_read!
        new(actor: nil).backfill_existing_as_read!
      end

      def initialize(actor:)
        @actor = actor
      end

      def mark_read(group_recording)
        raise ArgumentError, "group recording is required" if group_recording.blank?
        raise ArgumentError, "actor is required" if @actor.blank?
        unless group_recording.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE
          raise RecordingStudioMessages::Error, Copy.t("errors.not_a_conversation")
        end

        authorize_view!(group_recording)

        now = Time.current
        latest = RecordingStudioMessages.message_recordings(group_recording).last
        stamp = latest&.created_at || group_recording.recordable&.last_message_at || now
        upsert_cursor(
          group_recording: group_recording,
          last_read_at: stamp,
          last_read_message_recording_id: latest&.id,
          at: now
        )
        clear_message_received_notices!(group_recording, at: now)
      end

      def upsert_cursor(group_recording:, last_read_at:, last_read_message_recording_id:, at: Time.current)
        RecordingStudioMessages::MessageRead.upsert(
          {
            actor_type: actor_type,
            actor_id: @actor.id,
            message_group_recording_id: group_recording.id,
            last_read_at: last_read_at,
            last_read_message_recording_id: last_read_message_recording_id,
            created_at: at,
            updated_at: at
          },
          unique_by: UNIQUE_BY,
          update_only: %i[last_read_at last_read_message_recording_id]
        )
      end

      def unread?(group_recording)
        return false if @actor.blank? || group_recording.blank?
        return false unless group_recording.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE
        return false unless viewable?(group_recording)

        last_message_at = group_recording.recordable&.last_message_at
        return false if last_message_at.blank?

        read = RecordingStudioMessages::MessageRead.find_by(
          actor_type: actor_type,
          actor_id: @actor.id,
          message_group_recording_id: group_recording.id
        )
        return true if read.blank?

        last_message_at > read.last_read_at
      end

      def unread_count
        return 0 if @actor.blank?

        RecordingStudioMessages.my_group_recordings(actor: @actor, unread: true)
                               .except(:includes)
                               .unscope(:order)
                               .count
      end

      def unread_ids_among(group_ids)
        ids = Array(group_ids).compact
        return [] if @actor.blank? || ids.empty?

        RecordingStudio::Recording.unscoped
                                  .kept
                                  .where(id: ids, recordable_type: RecordingStudioMessages::MESSAGE_GROUP_TYPE)
                                  .joins(group_join)
                                  .joins(read_join)
                                  .where(UNREAD_SQL)
                                  .pluck(:id)
      end

      def backfill_existing_as_read!
        return unless defined?(RecordingStudioAccessible)
        return unless defined?(RecordingStudio::Access)
        return if ranked_roles.empty?

        grants = backfill_grant_scope
        RecordingStudio::Access.unscoped
                               .where(id: grants.reselect("recording_studio_accesses.id"))
                               .find_in_batches(batch_size: BACKFILL_BATCH) do |accesses|
          rows = backfill_rows_for(grants.where(id: accesses.map(&:id)))
          next if rows.empty?

          RecordingStudioMessages::MessageRead.insert_all(
            rows,
            unique_by: UNIQUE_BY,
            record_timestamps: false
          )
        end
      end

      private

      def authorize_view!(group_recording)
        return if viewable?(group_recording)

        raise RecordingStudioMessages::NotAuthorized, Copy.t("flashes.cannot_open")
      end

      def viewable?(group_recording)
        return false unless defined?(RecordingStudioAccessible)
        return false if @actor.blank? || group_recording.blank?

        RecordingStudioAccessible.authorized?(
          actor: @actor,
          recording: group_recording,
          role: :view
        )
      end

      def clear_message_received_notices!(group_recording, at:)
        return unless defined?(RecordingStudioNotifications::Notification)

        RecordingStudioNotifications::Notification
          .for_recipient(@actor)
          .of_type(RecordingStudioMessages::MESSAGE_RECEIVED_TYPE)
          .unread
          .where("metadata->>'message_group_id' = ?", group_recording.id.to_s)
          .update_all(read_at: at)
      end

      def backfill_grant_scope
        RecordingStudio::Access.unscoped
                               .where(role: ranked_roles)
                               .where(dependent_access_sql)
                               .joins(backfill_joins)
                               .where.not(recording_studio_message_groups: { last_message_at: nil })
      end

      def backfill_joins
        <<~SQL.squish
          INNER JOIN recording_studio_recordings access_recordings
            ON access_recordings.recordable_id = recording_studio_accesses.id
            AND access_recordings.recordable_type = #{quoted(ACCESS_TYPE)}
            AND #{RecordingStudio.kept_sql('access_recordings')}
          INNER JOIN recording_studio_recordings
            ON recording_studio_recordings.id = access_recordings.parent_recording_id
            AND recording_studio_recordings.recordable_type = #{quoted(RecordingStudioMessages::MESSAGE_GROUP_TYPE)}
            AND #{RecordingStudio.kept_sql('recording_studio_recordings')}
          INNER JOIN recording_studio_message_groups
            ON recording_studio_message_groups.id = recording_studio_recordings.recordable_id
        SQL
      end

      def backfill_rows_for(batch)
        now = Time.current
        rows = batch.pluck(
          "recording_studio_accesses.actor_type",
          "recording_studio_accesses.actor_id",
          "recording_studio_recordings.id",
          "recording_studio_message_groups.last_message_at"
        )
        rows.filter_map do |actor_type, actor_id, group_id, last_message_at|
          next if last_message_at.blank?

          {
            actor_type: actor_type,
            actor_id: actor_id,
            message_group_recording_id: group_id,
            last_read_at: last_message_at,
            created_at: now,
            updated_at: now
          }
        end
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
              AND #{RecordingStudio.kept_sql('manager_recordings')}
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

      def group_join
        <<~SQL.squish
          INNER JOIN recording_studio_message_groups
            ON recording_studio_message_groups.id = recording_studio_recordings.recordable_id
            AND recording_studio_recordings.recordable_type = #{quoted(RecordingStudioMessages::MESSAGE_GROUP_TYPE)}
        SQL
      end

      def read_join
        <<~SQL.squish
          LEFT JOIN recording_studio_message_reads
            ON recording_studio_message_reads.message_group_recording_id = recording_studio_recordings.id
            AND recording_studio_message_reads.actor_type = #{quoted(actor_type)}
            AND recording_studio_message_reads.actor_id = #{quoted(@actor.id)}
        SQL
      end

      def actor_type
        RecordingStudioAccessible::ActorType.for(@actor)
      end

      def quoted(value)
        RecordingStudio::Recording.connection.quote(value)
      end
    end
  end
end
