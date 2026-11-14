# frozen_string_literal: true

module RecordingStudioMessages
  # Block-scoped marker for the gem's own Message and MessageGroup writes.
  # Host write policies read +trusted_write_context+. Call +trusted_write+ only
  # from vetted services, around the write, after that service's own checks.
  module TrustedWrite
    THREAD_KEY = :recording_studio_messages_trusted_write
    ACTIONS = %i[create_group send_message rename_group].freeze

    Context = Data.define(:action, :mount_recording)

    class << self
      def trusted_write(action:, mount_recording:)
        unless action.is_a?(Symbol) && ACTIONS.include?(action)
          raise ArgumentError, "action must be :create_group, :send_message, or :rename_group"
        end

        previous = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = Context.new(action: action, mount_recording: mount_recording)
        begin
          yield
        ensure
          Thread.current[THREAD_KEY] = previous
        end
      end

      def context
        Thread.current[THREAD_KEY]
      end
    end
  end
end
