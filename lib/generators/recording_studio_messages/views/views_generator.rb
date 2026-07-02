# frozen_string_literal: true

require "rails/generators"

module RecordingStudioMessages
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../../app/views/recording_studio_messages", __dir__)

      desc "Copy RecordingStudioMessages overrideable views into the host application"

      def copy_views
        directory ".", "app/views/recording_studio_messages"
      end
    end
  end
end
