# frozen_string_literal: true

module RecordingStudioMessages
  module CopyHelper
    def messages_t(...)
      Copy.t(...)
    end

    def messages_copy(override, key, **)
      Copy.value(override, key, **)
    end
  end
end
