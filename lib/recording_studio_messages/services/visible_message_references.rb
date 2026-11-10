# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class VisibleMessageReferences
      def self.call(...)
        new(...).call
      end

      def initialize(message_recordings, actor:)
        @message_recordings = Array(message_recordings).compact
        @actor = actor
      end

      def call
        return {} if @message_recordings.empty? || @actor.blank?

        refs = MessageReference.where(message_recording_id: @message_recordings.map(&:id)).to_a
        return {} if refs.empty?

        index_visible(refs, load_targets(refs.map(&:target_recording_id)))
      end

      private

      def index_visible(refs, targets)
        allowed = allowed_ids(targets.values)
        refs.each_with_object({}) do |ref, index|
          next unless allowed.include?(ref.target_recording_id.to_s)

          (index[ref.message_recording_id.to_s] ||= []) << targets[ref.target_recording_id.to_s]
        end
      end

      def load_targets(ids)
        RecordingStudio::Recording.unscoped.where(id: ids).includes(:recordable).index_by do |recording|
          recording.id.to_s
        end
      end

      def allowed_ids(targets)
        live = targets.select { |recording| recording.trashed_at.blank? }
        return [] if live.empty?

        parents = load_parents(live.map(&:parent_recording_id).uniq.compact)
        live.group_by { |recording| recording.parent_recording_id.to_s }.flat_map do |parent_id, children|
          ids_for_parent(parents[parent_id], children)
        end
      end

      def ids_for_parent(parent, children)
        return [] if parent.blank?

        RecordingStudioAccessible.recordings_for(
          actor: @actor,
          parent_recording: parent,
          minimum_role: :view
        ).where(id: children.map(&:id)).map { |recording| recording.id.to_s }
      end

      def load_parents(ids)
        RecordingStudio::Recording.unscoped.where(id: ids, trashed_at: nil).index_by do |recording|
          recording.id.to_s
        end
      end
    end
  end
end
