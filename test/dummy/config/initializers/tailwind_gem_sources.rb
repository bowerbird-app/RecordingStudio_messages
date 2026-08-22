# frozen_string_literal: true

# Point Tailwind at the installed Flatpack and Recording Studio gems.
# The source globs also cover CI and mise paths; these links make local builds reliable.
if defined?(RecordingStudioRootSwitchable::TailwindSourceLinker)
  missing_link = %w[flat_pack recording_studio recording_studio_root_switchable].any? do |name|
    destination = Rails.root.join("vendor", name)
    !File.symlink?(destination) || !File.exist?(destination)
  end

  RecordingStudioRootSwitchable::TailwindSourceLinker.link!(rails_root: Rails.root) if missing_link
end
