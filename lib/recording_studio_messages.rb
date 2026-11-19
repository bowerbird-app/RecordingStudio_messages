# frozen_string_literal: true

require "active_record"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_notifications"
require "flat_pack"
require "recording_studio_messages/version"
require "recording_studio_messages/copy"
require "recording_studio_messages/engine_frontend"
require "recording_studio_messages/engine"
require "recording_studio_messages/metrics"
require "recording_studio_messages/configuration"
require "recording_studio/capabilities/messages"
require "recording_studio_messages/membership_lock"
require "recording_studio_messages/trusted_write"
require "recording_studio_messages/mount_access"
require "recording_studio_messages/contacts"
require "recording_studio_messages/public_contact"
require "recording_studio_messages/services/ensure_mount"
require "recording_studio_messages/services/create_group_people"
require "recording_studio_messages/services/create_group"
require "recording_studio_messages/services/rename_group"
require "recording_studio_messages/services/list_groups"
require "recording_studio_messages/services/my_group_recordings"
require "recording_studio_messages/services/message_reads"
require "recording_studio_messages/services/seen_by"
require "recording_studio_messages/services/inbox_page"
require "recording_studio_messages/services/inbox_card"
require "recording_studio_messages/inbox_card_registration"
require "recording_studio_messages/services/live_recording"
require "recording_studio_messages/services/recording_subtree"
require "recording_studio_messages/services/message_group_tags"
require "recording_studio_messages/services/uploaded_file"
require "recording_studio_messages/services/message_notice"
require "recording_studio_messages/services/notify_granted_actors"
require "recording_studio_messages/services/inbound_reply"
require "recording_studio_messages/composer_action"
require "recording_studio_messages/message_reference_slot"
require "recording_studio_messages/services/auto_link"
require "recording_studio_messages/services/message_reference_fallback"
require "recording_studio_messages/services/visible_message_references"
require "recording_studio_messages/services/message_references"
require "recording_studio_messages/services/send_message_persist"
require "recording_studio_messages/services/send_message"

module RecordingStudioMessages
  class Error < StandardError; end
  class NotAuthorized < Error; end

  MESSAGE_MOUNT_TYPE = "RecordingStudioMessages::MessageMount"
  MESSAGE_GROUP_TYPE = "RecordingStudioMessages::MessageGroup"
  MESSAGE_TYPE = "RecordingStudioMessages::Message"
  MESSAGE_RECEIVED_TYPE = :message_received
  MESSAGE_RECEIVED_PERSONAL_TYPE = :message_received_personal

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

    def create_group(mount_recording, actor:, title: nil, tags: nil, admin: nil, recipients: nil, body: nil)
      Services::CreateGroup.call(
        mount_recording,
        title: title,
        actor: actor,
        tags: tags,
        admin: admin,
        recipients: recipients,
        body: body
      )
    end

    def rename_group(group_recording:, title:, actor:)
      Services::RenameGroup.call(group_recording: group_recording, title: title, actor: actor)
    end

    def tagged_group_recordings(mount_recording:, tags:)
      Services::MessageGroupTags.recordings_for_mount(mount_recording, tags)
    end

    def send_message(...)
      Services::SendMessage.call(...)
    end

    def register_composer_action(key, **)
      configuration.composer_actions[key.to_s] = ComposerAction.from_register(key, **)
    end

    def register_message_embed(recordable_type, partial:)
      configuration.message_embeds[embed_type_name(recordable_type)] = partial
    end

    def composer_actions_for(group, actor, mount)
      configuration.composer_actions.values.select { |action| action.allowed?(group, actor, mount) }
    end

    def message_embed_partial(recordable_type)
      configuration.message_embeds[embed_type_name(recordable_type)]
    end

    def visible_message_references(...)
      Services::MessageReferences.visible_for(...)
    end

    def preview_text(body, references: [])
      Services::MessageReferences.fallback_body(body, references)
    end

    def auto_link(text)
      Services::AutoLink.call(text)
    end

    def granted_actors(group_recording)
      return [] unless defined?(RecordingStudioAccessible)
      return [] if group_recording.blank?

      RecordingStudioAccessible.access_recordings_for(group_recording).filter_map do |access_recording|
        access_recording.recordable&.actor
      end
    end

    def tag(group_recording, key:, recording:)
      Services::MessageGroupTags.tag(group_recording, key: key, recording: recording)
    end

    def untag(group_recording, key:, recording: nil)
      Services::MessageGroupTags.untag(group_recording, key: key, recording: recording)
    end

    def viewable_group_recordings(actor:, mount_recording: nil, tags: nil, unread: false, after: nil, limit: nil)
      Services::ListGroups.call(
        actor: actor,
        mount_recording: mount_recording,
        tags: tags,
        unread: unread,
        after: after,
        limit: limit
      )
    end

    def my_group_recordings(...)
      Services::MyGroupRecordings.call(...)
    end

    def mark_read(...)
      Services::MessageReads.mark_read(...)
    end

    def unread?(...)
      Services::MessageReads.unread?(...)
    end

    def unread_count(...)
      Services::MessageReads.unread_count(...)
    end

    def seen_by(...)
      Services::SeenBy.call(...)
    end

    def message_recordings(group_recording)
      return RecordingStudio::Recording.none if group_recording.blank?

      RecordingStudio::Recording.unscoped.kept.where(
        parent_recording_id: group_recording.id,
        recordable_type: MESSAGE_TYPE
      ).includes(:recordable, events: :actor).order(:created_at)
    end

    def register_integration!
      register_messages_capability!
      register_message_received_type!
      register_message_received_personal_type!
      register_message_received_reply_handler!
      MembershipLock.install_authorizer_wrap!
    end

    def public_contact_enabled?(mount_recording)
      PublicContact.enabled?(mount_recording)
    end

    def begin_public_contact(mount_recording:, name:, email:, body:, current_actor:, request:, session:, tags: nil,
                             source: nil)
      PublicContact.begin(
        mount_recording:, name:, email:, body:, current_actor:, request:, session:, tags:, source:
      )
    end

    def complete_public_contact(intent:, actor:, session: nil)
      PublicContact.complete(intent: intent, actor: actor, session: session)
    end

    def membership_locked?(mount_recording)
      MembershipLock.membership_locked?(mount_recording)
    end

    def membership_locked_for_group?(group_recording)
      MembershipLock.membership_locked_for_group?(group_recording)
    end

    def allow_membership_change(&)
      MembershipLock.allow_membership_change(&)
    end

    def trusted_write(...)
      TrustedWrite.trusted_write(...)
    end

    def trusted_write_context
      TrustedWrite.context
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

    def register_message_received_personal_type!
      return unless personal_notices_supported?

      RecordingStudioNotifications.register_notification_type(
        MESSAGE_RECEIVED_PERSONAL_TYPE,
        **personal_type_options
      )
    end

    def register_message_received_reply_handler!
      register_message_received_personal_type!
      return unless RecordingStudioNotifications.respond_to?(:register_reply_handler)

      handler = lambda { |notification:, recipient:, body:, attachments:|
        Services::InboundReply.call(notification:, recipient:, body:, attachments:)
      }
      RecordingStudioNotifications.register_reply_handler(MESSAGE_RECEIVED_TYPE, &handler)
      return unless personal_notices_supported?

      RecordingStudioNotifications.register_reply_handler(MESSAGE_RECEIVED_PERSONAL_TYPE, &handler)
    end

    def personal_notices_supported?
      return false unless defined?(RecordingStudioAccessible)

      authorization = RecordingStudioNotifications::Services::NotificationAuthorization
      authorization.respond_to?(:visible_for_reply?)
    rescue NameError
      false
    end

    def email_channel_registered?
      return false unless RecordingStudioNotifications.respond_to?(:channels)

      RecordingStudioNotifications.channels.registered?(:email)
    rescue StandardError
      false
    end

    def personal_default_channels
      email_channel_registered? ? %i[in_app email] : [:in_app]
    end

    def thread_key_supported?
      notify_accepts?(:thread_key)
    end

    def recording_supported?
      notify_accepts?(:recording)
    end

    def notify_accepts?(keyword)
      parameters = RecordingStudioNotifications::Services::Notify.instance_method(:initialize).parameters
      parameters.any? { |_, name| name == keyword }
    rescue NameError
      false
    end

    def embed_type_name(recordable_type)
      return recordable_type.name if recordable_type.is_a?(Class)

      recordable_type.to_s
    end

    def message_received_type_options
      {
        label: "Message received",
        description: "A new message arrived in a conversation you can see.",
        icon: :chat_bubble_left,
        category: :general,
        default_channels: [:in_app],
        available_channels: %i[in_app email],
        scope: :root
      }
    end

    def personal_type_options
      {
        label: "Your messages",
        description: "A new message in a conversation you're in.",
        icon: :chat_bubble_left,
        category: :general,
        default_channels: personal_default_channels,
        available_channels: %i[in_app email],
        scope: :global
      }
    end
  end
end
