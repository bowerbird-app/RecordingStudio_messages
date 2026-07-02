# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioMessages
  module Generators
    class ContainerGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :root, type: :boolean, default: false, desc: "Declare this container as a RecordingStudio root"
      class_option :parent_types, type: :array, default: [], desc: "Allowed RecordingStudio parent recordable types"

      def create_model
        template "container_model.rb", File.join("app/models", class_path, "#{file_name}.rb")
      end

      def create_migration
        migration_template "container_migration.rb", "db/migrate/create_#{table_name}.rb"
      end

      def print_next_steps
        say "Register #{class_name}, RecordingStudioMessages::MessageGroup, and RecordingStudioMessages::Message in RecordingStudio.config.recordable_types.", :green
        say "Add a RecordingStudioMessages config block for #{class_name} and configure recipient search/eligibility.", :green
        say "Seed or create the #{class_name} container recording explicitly before using message routes.", :green
        say "Use action authorization only for shared-root/private-child message creation; do not grant broad root access solely for creation.", :yellow
      end

      private

      def next_migration_number(dirname)
        ActiveRecord::Migration.next_migration_number(Time.now.utc.strftime("%Y%m%d%H%M%S"))
      end
    end
  end
end
