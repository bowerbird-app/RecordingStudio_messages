# frozen_string_literal: true

require_relative "api/access"
require_relative "api/registration"

module RecordingStudioMessages
  module Api
    module_function

    def register!(apis: [:public])
      return unless defined?(::RecordingStudioApi)

      Array(apis).each { |api| Registration.register!(api) }
    end
  end
end
