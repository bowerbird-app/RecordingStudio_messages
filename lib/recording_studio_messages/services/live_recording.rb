# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    module LiveRecording
      module_function

      def find(id)
        RecordingStudio::Recording.unscoped.kept.find_by(id: id) if id.present?
      end
    end
  end
end
