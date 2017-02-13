class RemoveUserFromResponses < ActiveRecord::Migration[5.0]
  def change
    change_table :responses do |t|
      t.remove :user_id
    end
  end
end
