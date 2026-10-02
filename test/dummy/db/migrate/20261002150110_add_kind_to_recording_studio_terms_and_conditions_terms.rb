# frozen_string_literal: true

class AddKindToRecordingStudioTermsAndConditionsTerms < ActiveRecord::Migration[8.1]
  def change
    table = :recording_studio_terms_and_conditions_terms
    return if column_exists?(table, :kind)

    add_column table, :kind, :string, null: false, default: "terms_and_condition"
  end
end
