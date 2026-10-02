# frozen_string_literal: true

class CreateRecordingStudioTermsAndConditionsTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_terms_and_conditions_terms, id: :uuid do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :created_at, null: false
    end
  end
end
