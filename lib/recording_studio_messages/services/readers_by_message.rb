# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class ReadersByMessage
      ACCESS_JOIN = <<~SQL.squish
        INNER JOIN recording_studio_accesses
          ON recording_studio_accesses.id = recording_studio_recordings.recordable_id
      SQL

      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, viewer:, messages: nil)
        @group_recording = group_recording
        @viewer = viewer
        @messages = messages
      end

      def call
        return {} unless enabled?
        return {} unless conversation?

        actors_by_key = current_actors_by_key
        return {} if actors_by_key.empty?

        group_reads(actors_by_key)
      end

      private

      def enabled?
        RecordingStudioMessages.configuration.read_receipts == true
      end

      def conversation?
        @group_recording.present? &&
          @group_recording.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE
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

      def group_reads(actors_by_key)
        grouped = Hash.new { |hash, key| hash[key] = [] }

        reads.each do |read|
          actor = actors_by_key[read_key(read)]
          next if actor.blank?

          message_id = message_id_for(read)
          next if message_id.blank?

          grouped[message_id] << [read.last_read_at, actor]
        end

        grouped.transform_values { |pairs| sort_readers(pairs) }
      end

      def reads
        RecordingStudioMessages::MessageRead.where(message_group_recording_id: @group_recording.id)
      end

      def message_id_for(read)
        id = read.last_read_message_recording_id
        matched = messages_by_id[id.to_s]
        return matched.id if matched

        fallback_message_id(read.last_read_at)
      end

      def fallback_message_id(last_read_at)
        return if last_read_at.blank?

        match = loaded_messages.reverse_each.find { |message| message.created_at <= last_read_at }
        match&.id
      end

      def loaded_messages
        @loaded_messages ||= Array(@messages.presence || RecordingStudioMessages.message_recordings(@group_recording))
      end

      def messages_by_id
        @messages_by_id ||= loaded_messages.index_by { |message| message.id.to_s }
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
