# frozen_string_literal: true

class AddBodyDigestToRecordingStudioTermsAndConditionsAcceptances < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_terms_and_conditions_acceptances, :body_digest, :string
  end
end
