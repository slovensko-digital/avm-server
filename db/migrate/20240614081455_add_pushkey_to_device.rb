class AddPushkeyToDevice < ActiveRecord::Migration[7.1]
  def change
    add_column :devices, :pushkey, :string, null: false
    remove_column :integrations, :pushkey
  end
end
