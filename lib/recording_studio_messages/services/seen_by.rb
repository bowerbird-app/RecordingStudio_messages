# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class SeenBy
      ACCESS_JOIN = <<~SQL.squish
        INNER JOIN recording_studio_accesses
          ON recording_studio_accesses.id = recording_studio_recordings.recordable_id
      SQL

      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, viewer:, latest_message: nil)
        @group_recording = group_recording
        @viewer = viewer
        @latest_message = latest_message
      end

      def call
        return [] unless enabled? && conversation? && latest.present?

        collect_readers
      end

      private

      def enabled?
        RecordingStudioMessages.configuration.read_receipts == true
      end

      def conversation?
        @group_recording.present? &&
          @group_recording.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE
      end

      def collect_readers
        actors_by_key = current_actors_by_key
        return [] if actors_by_key.empty?

        sort_readers(reader_pairs(actors_by_key))
      end

      def reader_pairs(actors_by_key)
        reads.filter_map do |read|
          actor = actors_by_key[read_key(read)]
          next if actor.blank?
          next unless reached_latest?(read)

          [read.last_read_at, actor]
        end
      end

      def latest
        @latest ||= @latest_message.presence || RecordingStudioMessages.message_recordings(@group_recording).last
      end

      def current_actors_by_key
        return {} unless defined?(RecordingStudioAccessible)
        return {} if ranked_roles.empty?

        access_recordings.each_with_object({}) do |recording, map|
          actor = recording.recordable&.actor
          next if actor.blank?
          next if viewer?(actor)

          map[actor_key(actor)] = actor
        end
      end

      def access_recordings
        RecordingStudioAccessible.access_recordings_for(@group_recording)
                                 .joins(ACCESS_JOIN)
                                 .where(recording_studio_accesses: { role: ranked_roles })
                                 .includes(recordable: :actor)
      end

      def reads
        RecordingStudioMessages::MessageRead.where(message_group_recording_id: @group_recording.id)
      end

      def reached_latest?(read)
        return true if read.last_read_message_recording_id.to_s == latest.id.to_s
        return false if read.last_read_at.blank?

        read.last_read_at >= latest.created_at
      end

      def sort_readers(pairs)
        pairs.sort_by { |read_at, actor| [-read_at.to_i, actor_name(actor)] }.map(&:last)
      end

      def actor_name(actor)
        actor.respond_to?(:name) ? actor.name.to_s : ""
      end

      def viewer?(actor)
        return false if @viewer.blank?

        actor_key(actor) == actor_key(@viewer)
      end

      def actor_key(actor)
        [RecordingStudioAccessible::ActorType.for(actor), actor.id.to_s]
      end

      def read_key(read)
        [read.actor_type, read.actor_id.to_s]
      end

      def ranked_roles
        return [] unless defined?(RecordingStudio::AccessRoles)

        RecordingStudio::AccessRoles::ORDER.keys
      end
    end
  end
end
