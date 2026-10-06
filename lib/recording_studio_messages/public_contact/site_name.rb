# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    module SiteName
      class << self
        def powered_by(recording)
          name = for_recording(recording)
          return if name.blank?

          "Powered by #{name}"
        end

        private

        def for_recording(recording)
          root = recording&.root_recording
          return if root.blank?

          settings_name(root).presence || recordable_name(root)
        end

        def settings_name(root)
          return unless defined?(RecordingStudioSiteSettings)
          return unless RecordingStudioSiteSettings.respond_to?(:name_for)

          RecordingStudioSiteSettings.name_for(root)
        end

        def recordable_name(root)
          recordable = root.recordable
          return unless recordable.respond_to?(:name)

          recordable.name
        end
      end
    end
  end
end
