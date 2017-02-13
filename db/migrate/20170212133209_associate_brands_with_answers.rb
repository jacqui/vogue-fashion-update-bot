class AssociateBrandsWithAnswers < ActiveRecord::Migration[5.0]
  def change
    change_table :possible_answers do |t|
      t.references :brand
      t.string :category
    end
  end
end
