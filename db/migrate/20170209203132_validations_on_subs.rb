class ValidationsOnSubs < ActiveRecord::Migration[5.0]
  def change
    add_index :subscriptions, [:user_id, :brand_id], unique: true
  end
end
