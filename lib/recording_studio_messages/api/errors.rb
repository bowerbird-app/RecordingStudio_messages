# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Errors
      module_function

      def wrap
        yield
      rescue RecordingStudioMessages::NotAuthorized => e
        raise ::RecordingStudioApi::AuthorizationError, e.message
      rescue RecordingStudioMessages::Error => e
        raise ::RecordingStudioApi::InvalidActionInputError, e.message
      rescue ArgumentError => e
        raise unless e.backtrace&.any? { |frame| frame.include?("recording_studio_messages/services/") }

        raise ::RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
