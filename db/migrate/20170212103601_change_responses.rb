class ChangeResponses < ActiveRecord::Migration[5.0]
  def change
    change_table :responses do |t|
      t.rename :option_id, :possible_answer_id
      t.references :user
    end
  end
end
