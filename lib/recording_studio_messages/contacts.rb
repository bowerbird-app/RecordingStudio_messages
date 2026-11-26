# frozen_string_literal: true

module RecordingStudioMessages
  module Contacts
    SEARCH_LIMIT = 20

    module_function

    def resolver(mount_recording)
      options = MountAccess.message_options(mount_recording&.parent_recording&.recordable_type)
      callable = options[:contacts]
      callable if callable.respond_to?(:call)
    end

    def enabled?(mount_recording)
      resolver(mount_recording).present?
    end

    def can_start?(mount:, actor:)
      return false if mount.blank? || actor.blank?
      return false unless enabled?(mount)

      RecordingStudioAccessible.authorized?(actor: actor, recording: mount, role: :edit)
    end

    def search(mount:, actor:, query: "")
      text = query.to_s.strip
      return [] if text.blank?

      call(mount: mount, actor: actor, query: text).first(SEARCH_LIMIT)
    end

    def allowlist(mount:, actor:)
      call(mount: mount, actor: actor, query: "")
    end

    def resolve!(mount:, actor:, recipients:)
      require_start!(mount, actor)
      selected = Array(recipients)
      raise RecordingStudioMessages::Error, Copy.t("errors.pick_recipient") if selected.empty?

      people, unknown = match_recipients(selected, allowlist(mount: mount, actor: actor))
      unknown_recipient!(unknown) if unknown.any?

      people
    end

    def require_start!(mount, actor)
      raise RecordingStudioMessages::Error, Copy.t("errors.contacts_off") unless enabled?(mount)
      return if can_start?(mount: mount, actor: actor)

      raise RecordingStudioMessages::NotAuthorized, Copy.t("errors.cannot_start")
    end

    def call(mount:, actor:, query: "")
      callable = resolver(mount)
      return [] if callable.blank? || actor.blank? || mount.blank?

      Array(callable.call(actor: actor, mount: mount, query: query.to_s)).compact
    end

    def token(actor)
      identity(actor).join(":")
    end

    def display_name(actor)
      return actor.name if actor.respond_to?(:name) && actor.name.present?
      return actor.email if actor.respond_to?(:email) && actor.email.present?

      actor.class.name.demodulize
    end

    def identity(item)
      return string_identity(item) if item.is_a?(String)
      return hash_identity(item) if item.is_a?(Hash)
      return [item.class.name, item.id.to_s] if item.respond_to?(:id)

      [item.class.name, item.to_s]
    end

    def string_identity(item)
      type, id = item.split(":", 2)
      [type.to_s, id.to_s]
    end

    def hash_identity(item)
      [(item[:type] || item["type"]).to_s, (item[:id] || item["id"]).to_s]
    end

    def match_recipients(selected, allowed)
      index = index_by_identity(allowed)
      unknown = []
      people = selected.map do |item|
        person = index[identity(item)] if present_identity?(item)
        unknown << token(item) if person.blank?
        person
      end
      [people, unknown]
    end

    def index_by_identity(actors)
      actors.each_with_object({}) do |actor, index|
        next if actor.blank?

        index[identity(actor)] = actor
      end
    end

    def present_identity?(item)
      return false if item.blank?

      type, id = identity(item)
      type.present? && id.present?
    end

    def unknown_recipient!(names)
      raise RecordingStudioMessages::Error, Copy.t("errors.unknown_recipient", names: names.uniq.join(", "))
    end
  end
end
