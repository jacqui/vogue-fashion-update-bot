class MoveTypeToQuestions < ActiveRecord::Migration[5.0]
  def change
    change_table :questions do |t|
      t.string :type
    end

    change_table :possible_answers do |t|
      t.remove :type
    end
  end
end
