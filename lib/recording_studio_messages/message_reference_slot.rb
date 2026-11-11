# frozen_string_literal: true

module RecordingStudioMessages
  MessageReferenceSlot = Data.define(:recording) do
    def unavailable?
      recording.nil?
    end
  end
end
