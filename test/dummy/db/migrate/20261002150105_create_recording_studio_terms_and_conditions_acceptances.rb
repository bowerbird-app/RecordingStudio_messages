# frozen_string_literal: true

class CreateRecordingStudioTermsAndConditionsAcceptances < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_terms_and_conditions_acceptances, id: :uuid do |t|
      t.string :actor_type, null: false
      t.uuid :actor_id, null: false
      t.uuid :terms_recording_id, null: false
      t.uuid :terms_id, null: false
      t.datetime :accepted_at, null: false
      t.datetime :created_at, null: false
    end

    add_acceptance_indexes
  end

  private

  def add_acceptance_indexes
    add_index :recording_studio_terms_and_conditions_acceptances, %i[actor_type actor_id],
              name: "index_rstac_acceptances_on_actor"
    add_index :recording_studio_terms_and_conditions_acceptances, :terms_recording_id,
              name: "index_rstac_acceptances_on_terms_recording_id"
    add_index :recording_studio_terms_and_conditions_acceptances, :terms_id,
              name: "index_rstac_acceptances_on_terms_id"
    add_index :recording_studio_terms_and_conditions_acceptances,
              %i[actor_type actor_id terms_recording_id terms_id],
              unique: true,
              name: "index_rstac_acceptances_on_actor_and_version"
  end
end
