class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents, id: :uuid do |t|
      t.json :parameters
      t.timestamps
    end
  end
end
