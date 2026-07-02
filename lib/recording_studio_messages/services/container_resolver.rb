# frozen_string_literal: true

module RecordingStudioMessages
  class ContainerResolver
    Result = Struct.new(:recording, :error, keyword_init: true) do
      def success? = recording.present?
    end

    def initialize(messages_config:, params: {})
      @messages_config = messages_config
      @params = params
    end

    def resolve
      @messages_config.validate!
      return by_recording_id if param(:container_recording_id).present?

      candidates = RecordingStudio::Recording.unscoped.where(recordable_type: @messages_config.container_type).limit(2).to_a
      return Result.new(recording: candidates.first) if candidates.one?

      if candidates.empty?
        Result.new(error: "No #{@messages_config.container_type} recording exists. Seed or create the container recording first.")
      else
        Result.new(error: "Multiple #{@messages_config.container_type} recordings exist. Pass container_recording_id explicitly.")
      end
    end

    private

    def by_recording_id
      recording = RecordingStudio::Recording.unscoped.find_by(id: param(:container_recording_id))
      return Result.new(error: "Container recording was not found.") unless recording
      return Result.new(error: "Container recording must be #{@messages_config.container_type}.") unless recording.recordable_type == @messages_config.container_type

      Result.new(recording: recording)
    end

    def param(key)
      @params.respond_to?(:[]) ? @params[key] || @params[key.to_s] : nil
    end
  end
end
