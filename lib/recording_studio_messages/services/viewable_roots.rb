# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class ViewableRoots
      def self.ids_for(actor)
        new(actor).ids
      end

      def initialize(actor)
        @actor = actor
      end

      def ids
        return [] if @actor.blank?

        relation = root_ids
        return if relation.nil?

        relation.pluck(:id).map(&:to_s)
      end

      private

      def root_ids
        return unless defined?(RecordingStudioAccessible)
        return unless RecordingStudioAccessible.respond_to?(:authorized_root_recording_ids)
        return if batch_unavailable?

        RecordingStudioAccessible.authorized_root_recording_ids(actor: @actor, role: :view)
      end

      def batch_unavailable?
        RecordingStudioAccessible.respond_to?(:authorized_root_recording_ids_supported?) &&
          !RecordingStudioAccessible.authorized_root_recording_ids_supported?
      end
    end
  end
end
