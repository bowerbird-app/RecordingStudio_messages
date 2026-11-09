# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    module LiveRecording
      module_function

      def find(id)
        RecordingStudio::Recording.unscoped.find_by(id: id, trashed_at: nil) if id.present?
      end
    end
  end
end
