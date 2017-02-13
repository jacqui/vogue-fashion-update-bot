class AddFollowupToQuestions < ActiveRecord::Migration[5.0]
  def change
    add_column :questions, :followup, :boolean, default: false
  end
end
