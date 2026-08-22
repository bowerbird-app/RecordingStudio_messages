# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class EnsureMount
      def self.call(...)
        new(...).call
      end

      def initialize(parent_recording, key:, actor: nil)
        @parent_recording = parent_recording
        @key = key.to_s
        @actor = actor
      end

      def call
        validate!
        existing = @parent_recording.message_mount(@key)
        return existing if existing

        @parent_recording.record(
          RecordingStudioMessages::MessageMount,
          actor: @actor,
          parent_recording: @parent_recording
        ) do |mount|
          mount.key = @key
        end
      end

      private

      def validate!
        raise ArgumentError, "parent recording is required" if @parent_recording.blank?
        raise ArgumentError, "mount key is required" if @key.blank?
        unless RecordingStudio.capability_enabled?(:messages, for: @parent_recording.recordable)
          raise RecordingStudioMessages::Error, "Messages is not enabled on this type"
        end

        allowed = allowed_keys
        return if allowed.empty? || allowed.include?(@key)

        raise RecordingStudioMessages::Error, "Mount key #{@key} is not enabled on this type"
      end

      def allowed_keys
        options = RecordingStudio.capability_options(:messages, for: @parent_recording.recordable) || {}
        Array(options[:keys] || options[:key]).map(&:to_s)
      end
    end
  end
end
