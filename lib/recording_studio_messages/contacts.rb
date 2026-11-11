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
      call(mount: mount, actor: actor, query: query).first(SEARCH_LIMIT)
    end

    def allowlist(mount:, actor:)
      call(mount: mount, actor: actor, query: "")
    end

    def resolve!(mount:, actor:, recipients:)
      require_start!(mount, actor)
      selected = Array(recipients).compact
      raise RecordingStudioMessages::Error, Copy.t("errors.pick_recipient") if selected.empty?

      allowed = index_by_identity(allowlist(mount: mount, actor: actor))
      selected.map { |item| allowed[identity(item)] || unknown_recipient! }
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

    def identity(item)
      if item.is_a?(Hash)
        type = item[:type] || item["type"]
        id = item[:id] || item["id"]
        [type.to_s, id.to_s]
      else
        [item.class.name, item.id.to_s]
      end
    end

    def index_by_identity(actors)
      actors.each_with_object({}) do |actor, index|
        next if actor.blank?

        index[identity(actor)] = actor
      end
    end

    def unknown_recipient!
      raise RecordingStudioMessages::Error, Copy.t("errors.unknown_recipient")
    end
  end
end
