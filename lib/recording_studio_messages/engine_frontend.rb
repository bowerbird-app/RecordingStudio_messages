# frozen_string_literal: true

module RecordingStudioMessages
  module EngineFrontend
    extend ActiveSupport::Concern

    included do
      initializer "recording_studio_messages.assets" do |app|
        app.config.assets.paths << root.join("app/javascript")
      end

      initializer "recording_studio_messages.importmap", before: "importmap" do |app|
        next unless app.config.respond_to?(:importmap)

        app.config.importmap.paths << root.join("config/importmap.rb")
      end

      initializer "recording_studio_messages.metrics" do
        config.to_prepare { RecordingStudioMessages::Metrics.register! }
      end
    end
  end
end
