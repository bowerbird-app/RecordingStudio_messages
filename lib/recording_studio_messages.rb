# frozen_string_literal: true

require "active_record"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_notifications"
require "flat_pack"
require "recording_studio_messages/version"
require "recording_studio_messages/engine"
require "recording_studio_messages/configuration"
require "recording_studio/capabilities/messages"
require "recording_studio_messages/services/ensure_mount"
require "recording_studio_messages/services/create_group"
require "recording_studio_messages/services/uploaded_file"
require "recording_studio_messages/services/notify_granted_actors"
require "recording_studio_messages/services/send_message"

module RecordingStudioMessages
  class Error < StandardError; end
  class NotAuthorized < Error; end

  MESSAGE_MOUNT_TYPE = "RecordingStudioMessages::MessageMount"
  MESSAGE_GROUP_TYPE = "RecordingStudioMessages::MessageGroup"
  MESSAGE_TYPE = "RecordingStudioMessages::Message"
  MESSAGE_RECEIVED_TYPE = :message_received

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def ensure_mount(parent_recording, key:, actor: nil)
      Services::EnsureMount.call(parent_recording, key: key, actor: actor)
    end

    def create_group(mount_recording, title:, actor:)
      Services::CreateGroup.call(mount_recording, title: title, actor: actor)
    end

    def send_message(...)
      Services::SendMessage.call(...)
    end

    def granted_actors(group_recording)
      return [] unless defined?(RecordingStudioAccessible)
      return [] if group_recording.blank?

      RecordingStudioAccessible.access_recordings_for(group_recording).filter_map do |access_recording|
        access_recording.recordable&.actor
      end
    end

    def message_recordings(group_recording)
      return RecordingStudio::Recording.none if group_recording.blank?

      RecordingStudio::Recording.unscoped.where(
        parent_recording_id: group_recording.id,
        recordable_type: MESSAGE_TYPE,
        trashed_at: nil
      ).includes(:recordable).order(:created_at)
    end

    def register_integration!
      register_messages_capability!
      register_message_received_type!
    end

    def register_messages_capability!
      RecordingStudio.register_capability(
        :messages,
        recording_methods: RecordingStudio::Capabilities::Messages::RecordingMethods,
        source: "recording_studio_messages",
        child_recordables: [MESSAGE_MOUNT_TYPE]
      )
    end

    def register_message_received_type!
      return if RecordingStudioNotifications.notification_types.registered?(MESSAGE_RECEIVED_TYPE)

      RecordingStudioNotifications.register_notification_type(
        MESSAGE_RECEIVED_TYPE,
        **message_received_type_options
      )
    end

    def message_received_type_options
      {
        label: "Message received",
        description: "A new message arrived in a conversation you can see.",
        icon: :chat_bubble_left,
        category: :general,
        default_channels: [:in_app],
        available_channels: [:in_app],
        scope: :root
      }
    end
  end
end
