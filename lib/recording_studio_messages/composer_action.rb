# frozen_string_literal: true

module RecordingStudioMessages
  ComposerAction = Data.define(:key, :label, :icon, :title, :size, :partial, :src, :condition) do
    def self.from_register(key, **attrs)
      ensure_single_body!(attrs)
      new(key: key.to_s, condition: attrs[:if], **body_attrs(attrs))
    end

    def self.ensure_single_body!(attrs)
      return unless attrs[:partial].present? == attrs[:src].present?

      raise ArgumentError, "register_composer_action requires exactly one of partial: or src:"
    end

    def self.body_attrs(attrs)
      {
        label: attrs.fetch(:label),
        icon: attrs.fetch(:icon),
        title: attrs[:title],
        size: attrs.fetch(:size, :sm),
        partial: attrs[:partial],
        src: attrs[:src]
      }
    end

    def allowed?(group, actor, mount)
      return true if condition.nil?

      condition.call(group, actor, mount)
    end

    def modal_title
      title.presence || label
    end

    def modal_size
      size.presence || :sm
    end

    def lazy?
      src.present?
    end

    def resolved_src(group, actor, mount)
      return if src.blank?
      return src.call(group, actor, mount) if src.respond_to?(:call)

      src.to_s
    end
  end
end
