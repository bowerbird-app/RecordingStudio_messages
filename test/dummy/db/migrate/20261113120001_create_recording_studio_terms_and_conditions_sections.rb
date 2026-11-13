# frozen_string_literal: true

class CreateRecordingStudioTermsAndConditionsSections < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_terms_and_conditions_sections, id: :uuid do |t|
      t.string :heading, null: false
      t.integer :position, null: false, default: 0
      t.datetime :created_at, null: false
    end
  end
end
