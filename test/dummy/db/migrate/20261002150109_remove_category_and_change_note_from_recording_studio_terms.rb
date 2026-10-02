# frozen_string_literal: true

class RemoveCategoryAndChangeNoteFromRecordingStudioTerms < ActiveRecord::Migration[8.1]
  def up
    table = :recording_studio_terms_and_conditions_terms
    drop_terms_index(table, "index_rstac_terms_on_category")
    drop_terms_index(table, "index_rstac_terms_on_kind")
    remove_column table, :category if column_exists?(table, :category)
    remove_column table, :change_note if column_exists?(table, :change_note)
    remove_column table, :kind if column_exists?(table, :kind)
  end

  def down
    # 0.4.0 does not ship category or change_note.
  end

  private

  def drop_terms_index(table, name)
    remove_index table, name: name if index_name_exists?(table, name)
  end
end
