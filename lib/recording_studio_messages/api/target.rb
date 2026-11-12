# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Target
      module_function

      def actor(context)
        return context.actor if context.respond_to?(:actor) && context.actor.present?

        context.access_grant&.actor
      end

      def authorize!(context, recording, role)
        context.access_grant.authorize!(recording: recording, role: role)
      end

      def recording(context, type)
        found = recording_from(context)
        raise ::RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if found.nil?
        unless found.recordable_type == type
          raise ::RecordingStudioApi::NotFoundError, "Resource type does not match #{type}"
        end

        found
      end

      def recording_from(context)
        if context.respond_to?(:recording) && context.recording
          context.recording
        else
          id = context.params[:id]
          return if id.blank?

          context.access_grant.accessible_recordings.find_by(id: id)
        end
      end

      def serialize(recording)
        base_payload(recording).merge(recordable_fields(recording.recordable))
      end

      def base_payload(recording)
        {
          id: recording.id,
          type: recording.recordable_type.to_s.demodulize,
          root_id: recording.root_recording_id,
          parent_id: recording.parent_recording_id,
          created_at: recording.created_at
        }
      end

      def recordable_fields(recordable)
        fields = {}
        fields[:key] = recordable.key if recordable.respond_to?(:key)
        fields[:title] = recordable.title if recordable.respond_to?(:title)
        fields[:body] = recordable.body if recordable.respond_to?(:body)
        fields
      end
    end
  end
end
