class AddActionToPossibleAnswers < ActiveRecord::Migration[5.0]
  def change
    add_column :possible_answers, :action, :string
  end
end
