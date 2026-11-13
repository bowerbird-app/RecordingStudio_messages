# frozen_string_literal: true

class CreateRecordingStudioTermsAndConditionsClauses < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_terms_and_conditions_clauses, id: :uuid do |t|
      t.text :body, null: false
      t.integer :position, null: false, default: 0
      t.datetime :created_at, null: false
    end
  end
end
