class CreateMessageContainers < ActiveRecord::Migration[8.1]
  def change
    create_table :site_messages, id: :uuid do |t|
      t.string :name
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    create_table :support_messages, id: :uuid do |t|
      t.string :name
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
  end
end
