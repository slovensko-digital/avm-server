class AddLastSignedAtToDocument < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :last_signed_at, :datetime
    Document.update_all('last_signed_at = updated_at')
    change_column_null :documents, :last_signed_at, false
  end
end
