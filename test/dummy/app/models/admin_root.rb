# frozen_string_literal: true

class AdminRoot < ApplicationRecord
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  RecordingStudio.enable_capability(:accessible, on: self)

  recording_studio_admin_sections do
    section :root
    section :site_settings
    section :terms
  end
end
