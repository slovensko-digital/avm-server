class AddIntegrationsAndDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :devices, id: :uuid do |t|
      t.string :registration_id, null: false
      t.string :platform, null: false
      t.string :display_name, null: false
      t.string :public_key, null: false

      t.timestamps
    end

    create_table :integrations, id: :uuid do |t|
      t.string :platform, null: false
      t.string :display_name, null: false
      t.string :public_key, null: false
      t.string :pushkey, null: false

      t.timestamps
    end

    create_join_table :devices, :integrations, column_options: {type: :uuid}
    add_index :devices_integrations, [:device_id, :integration_id], unique: true
  end
end
