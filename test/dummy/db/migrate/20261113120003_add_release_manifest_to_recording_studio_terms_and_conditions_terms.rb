# frozen_string_literal: true

class AddReleaseManifestToRecordingStudioTermsAndConditionsTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_terms_and_conditions_terms, :release_manifest, :jsonb
  end
end
