class AddToken < ActiveRecord::Migration[7.1]
  def change
    create_table :tokens do |t|
      t.string :namespace, null: false
      t.string :key, null: false
      t.string :value, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :tokens, [:namespace, :key], unique: true
  end
end
