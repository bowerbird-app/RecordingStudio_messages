# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Target
      module_function

      def authorize!(context, recording, role)
        context.access_grant.authorize!(recording: recording, role: role)
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
          created_at: recording.created_at&.utc&.iso8601
        }
      end

      def recordable_fields(recording)
        recordable = recording.recordable
        type = recording.recordable_type
        return { key: recordable.key } if type == MESSAGE_MOUNT_TYPE
        return { title: recordable.title } if type == MESSAGE_GROUP_TYPE
        return { body: recordable.body } if type == MESSAGE_TYPE

        {}
      end
    end
  end
end
