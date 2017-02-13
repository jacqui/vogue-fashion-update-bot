class CreateResponses < ActiveRecord::Migration[5.0]
  def change
    create_table :responses do |t|
      t.integer :order
      t.integer :question_id
      t.integer :option_id
      t.text :text
      t.string :category
      t.integer :quantity

      t.timestamps
    end
  end
end
