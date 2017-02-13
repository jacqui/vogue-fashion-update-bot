class AddNextQuestionIdToResponses < ActiveRecord::Migration[5.0]
  def change
    add_column :responses, :next_question_id, :integer
  end
end
