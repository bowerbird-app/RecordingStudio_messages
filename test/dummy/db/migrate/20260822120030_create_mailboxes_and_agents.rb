# frozen_string_literal: true

class CreateMailboxesAndAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :mailboxes, id: :uuid do |t|
      t.string :name, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    create_table :agents, id: :uuid do |t|
      t.string :name, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_column :users, :name, :string
  end
end
