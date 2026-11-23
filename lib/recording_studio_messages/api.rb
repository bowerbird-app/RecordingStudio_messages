# frozen_string_literal: true

require_relative "api/access"
require_relative "api/placement"

module RecordingStudioMessages
  module Api
    module_function

    def place(api:, at:, mount:, preset: nil, actions: nil, names: {}, descriptions: {}, titles: {}, tags: nil,
              tag_group: nil)
      Placement.place(
        api:, at:, mount:, preset:, actions:, names:, descriptions:, titles:, tags:, tag_group:
      )
    end
  end
end
