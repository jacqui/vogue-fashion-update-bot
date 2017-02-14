class AddNextQuestionIdToPossibleAnswers < ActiveRecord::Migration[5.0]
  def change
    add_column :possible_answers, :next_question_id, :integer
  end
end
