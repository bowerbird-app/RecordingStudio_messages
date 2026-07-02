# frozen_string_literal: true

class Create<%= table_name.camelize %> < ActiveRecord::Migration[8.1]
  def change
    create_table :<%= table_name %>, id: :uuid do |t|
      t.string :name
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
