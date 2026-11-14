# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class RecordingSubtree
      class NotInTree < StandardError; end

      def self.under_parent?(recordings, ancestor)
        new(recordings, ancestor).contained?
      end

      def initialize(recordings, ancestor)
        @ancestor_id = ancestor.id.to_s
        @loaded = { @ancestor_id => ancestor }
        recordings.each { |recording| @loaded[recording.id.to_s] = recording }
        @frontier = recordings.map { |recording| recording.id.to_s }.uniq - [@ancestor_id]
        @seen = @frontier.index_with(true)
      end

      def contained?
        advance until @frontier.empty?
        true
      rescue NotInTree
        false
      end

      private

      def advance
        parents = parent_ids_for_frontier
        load_missing(parents)
        @frontier = next_frontier(parents)
      end

      def parent_ids_for_frontier
        @frontier.map { |id| parent_id_for(id) }
      end

      def parent_id_for(id)
        recording = @loaded[id]
        raise NotInTree if recording.nil?

        recording.parent_recording_id&.to_s.tap { |parent_id| raise NotInTree if parent_id.nil? }
      end

      def load_missing(parent_ids)
        missing = parent_ids.uniq - @loaded.keys
        return if missing.empty?

        RecordingStudio::Recording.unscoped.kept.where(id: missing).find_each do |recording|
          @loaded[recording.id.to_s] = recording
        end
        raise NotInTree unless missing.all? { |id| @loaded.key?(id) }
      end

      def next_frontier(parent_ids)
        parent_ids.filter_map { |parent_id| continue_from(parent_id) }
      end

      def continue_from(parent_id)
        return if parent_id == @ancestor_id
        raise NotInTree if @seen[parent_id]

        @seen[parent_id] = true
        parent_id
      end
    end
  end
end
