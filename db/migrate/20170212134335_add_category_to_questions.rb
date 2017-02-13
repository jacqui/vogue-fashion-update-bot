class AddCategoryToQuestions < ActiveRecord::Migration[5.0]
  def change
    change_table :questions do |t|
      t.string :category
    end
  end
end
