# frozen_string_literal: true

class AddProvenanceToRecordingStudioTermsAndConditionsAcceptances < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_terms_and_conditions_acceptances, :provenance, :jsonb, null: false, default: {}
  end
end
