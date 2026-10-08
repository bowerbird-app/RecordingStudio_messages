# frozen_string_literal: true

require "i18n"

module RecordingStudioMessages
  module Copy
    PREFIX = "recording_studio.messages"
    UNSET = Object.new.freeze

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end

    def l(object, **)
      I18n.l(object, **)
    end

    def provided?(value)
      !value.equal?(UNSET)
    end

    def value(override, key, **)
      provided?(override) ? override : t(key, **)
    end
  end
end
