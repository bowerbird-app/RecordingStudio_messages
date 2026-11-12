# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Target
      module_function

      def authorize!(context, recording, role)
        context.access_grant.authorize!(recording: recording, role: role)
      end

      def accessible_recording(context, type)
        id = context.params[:id]
        found = context.access_grant.accessible_recordings.find_by(id: id) if id.present?
        raise ::RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if found.nil?
        unless found.recordable_type == type
          raise ::RecordingStudioApi::NotFoundError, "Resource type does not match #{type}"
        end

        found
      end

      def serialize(recording)
        base_payload(recording).merge(recordable_fields(recording))
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

      def recordable_fields(recording)
        recordable = recording.recordable
        type = recording.recordable_type
        return Registration.serialize_mount(recordable) if type == MESSAGE_MOUNT_TYPE
        return Registration.serialize_group(recordable) if type == MESSAGE_GROUP_TYPE
        return { body: recordable.body } if type == MESSAGE_TYPE

        {}
      end
    end
  end
end
