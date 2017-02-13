class CreatePossibleAnswers < ActiveRecord::Migration[5.0]
  def change
    create_table :possible_answers do |t|
      t.references :question, foreign_key: true
      t.string :value
      t.string :type
      t.integer :order

      t.timestamps
    end
  end
end
