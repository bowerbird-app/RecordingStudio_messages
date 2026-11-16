# frozen_string_literal: true

class CreateRecordingStudioTermsAndConditionsLibraries < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_terms_and_conditions_libraries, id: :uuid do |t|
      t.datetime :created_at, null: false
    end
  end
end
