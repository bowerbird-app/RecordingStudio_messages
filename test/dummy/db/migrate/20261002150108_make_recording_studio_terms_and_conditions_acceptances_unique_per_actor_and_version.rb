# frozen_string_literal: true

class MakeRecordingStudioTermsAndConditionsAcceptancesUniquePerActorAndVersion < ActiveRecord::Migration[8.1]
  def change
    remove_index :recording_studio_terms_and_conditions_acceptances,
                 name: "index_rstac_acceptances_on_actor_and_version",
                 if_exists: true
    add_index :recording_studio_terms_and_conditions_acceptances,
              %i[actor_type actor_id terms_recording_id terms_id],
              unique: true,
              name: "index_rstac_acceptances_on_actor_and_version"
  end
end
