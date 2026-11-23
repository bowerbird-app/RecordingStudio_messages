# frozen_string_literal: true

require_relative "api/access"
require_relative "api/placement"

module RecordingStudioMessages
  module Api
    module_function

    def place(api:, at:, mount: nil, preset: nil, actions: nil, names: {}, descriptions: {}, tags: nil)
      Placement.place(api:, at:, mount:, preset:, actions:, names:, descriptions:, tags:)
    end
  end
end
