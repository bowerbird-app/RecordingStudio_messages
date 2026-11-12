# frozen_string_literal: true

require_relative "api/access"
require_relative "api/registration"

module RecordingStudioMessages
  module Api
    module_function

    def register!
      return unless defined?(::RecordingStudioApi)
      return if @registered

      ::RecordingStudioApi.configuration.each_api do |api|
        Registration.register!(api.name)
      end
      @registered = true
    end
  end
end
