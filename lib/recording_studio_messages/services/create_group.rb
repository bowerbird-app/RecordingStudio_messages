# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class CreateGroup
      def self.call(...)
        new(...).call
      end

      def initialize(mount_recording, actor:, title: nil, tags: nil, admin: nil, recipients: nil, body: nil)
        @mount_recording = mount_recording
        @title = title.to_s.strip
        @actor = actor
        @tags = tags
        @admin = admin
        @recipients = recipients.nil? ? nil : Array(recipients)
        @body = body.to_s
      end

      def call
        validate!
        persist!
      end

      private

      def persist!
        checked = MessageGroupTags.normalize_tags(@tags)
        members = resolved_members
        @title = default_title(members) if @title.blank? && members
        RecordingStudio::Recording.transaction { write!(checked, members) }
      end

      def write!(checked, members)
        group_recording = record_group
        CreateGroupPeople.new(
          mount: @mount_recording, actor: @actor, admin: @admin, members: members
        ).grant!(group_recording)
        write_tags(group_recording, checked)
        send_first_message!(group_recording) if members
        group_recording
      end

      def write_tags(group_recording, checked)
        checked.each do |key, recording|
          MessageGroupTags.tag(group_recording, key: key, recording: recording)
        end
      end

      def record_group
        group = RecordingStudioMessages::MessageGroup.new(title: @title)
        RecordingStudio.record!(
          action: "created",
          recordable: group,
          root_recording: @mount_recording.root_recording || @mount_recording,
          parent_recording: @mount_recording,
          actor: @actor
        ).recording
      end

      def validate!
        raise ArgumentError, "mount recording is required" if @mount_recording.blank?
        raise ArgumentError, "actor is required" if @actor.blank?
        raise ArgumentError, "title is required" if @title.blank? && @recipients.nil?

        validate_start! if @recipients
        return if mount_recordable?

        raise RecordingStudioMessages::Error, "Groups must be created under a message mount"
      end

      def validate_start!
        raise RecordingStudioMessages::Error, Copy.t("errors.write_message") if @body.strip.blank?
        return if @title.length <= MessageGroup::TITLE_MAX

        raise RecordingStudioMessages::Error, Copy.t("errors.title_too_long")
      end

      def resolved_members
        return if @recipients.nil?

        Contacts.resolve!(mount: @mount_recording, actor: @actor, recipients: @recipients)
      end

      def default_title(members)
        names = title_people(members).map { |person| actor_name(person) }.compact_blank
        names.presence&.join(", ")&.truncate(MessageGroup::TITLE_MAX) || Copy.t("inbox.new_untitled")
      end

      def title_people(members)
        seen = {}
        ([@actor] + Array(members)).filter_map do |person|
          next if person.blank?

          key = Contacts.identity(person)
          next if seen[key]

          seen[key] = true
          person
        end
      end

      def actor_name(actor)
        return actor.name if actor.respond_to?(:name) && actor.name.present?
        return actor.email if actor.respond_to?(:email) && actor.email.present?

        actor.class.name.demodulize
      end

      def mount_recordable?
        @mount_recording.recordable_type == "RecordingStudioMessages::MessageMount"
      end

      def send_first_message!(group_recording)
        RecordingStudioMessages.send_message(
          group_recording: group_recording,
          body: @body,
          actor: @actor,
          files: [],
          notify: true,
          url: RecordingStudioMessages::Engine.routes.url_helpers.message_group_path(group_recording)
        )
      end
    end
  end
end
