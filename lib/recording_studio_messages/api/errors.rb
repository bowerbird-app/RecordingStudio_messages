# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Errors
      module_function

      def wrap
        yield
      rescue RecordingStudioMessages::NotAuthorized => e
        raise ::RecordingStudioApi::AuthorizationError, e.message
      rescue RecordingStudioMessages::Error, ArgumentError => e
        raise ::RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
