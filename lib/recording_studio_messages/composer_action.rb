# frozen_string_literal: true

module RecordingStudioMessages
  ComposerAction = Data.define(:key, :label, :icon, :partial, :condition) do
    def allowed?(group, actor, mount)
      return true if condition.nil?

      condition.call(group, actor, mount)
    end
  end
end
