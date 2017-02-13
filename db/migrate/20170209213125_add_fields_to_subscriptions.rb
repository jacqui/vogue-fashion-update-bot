class AddFieldsToSubscriptions < ActiveRecord::Migration[5.0]
  def change
    change_table :subscriptions do |t|
      t.datetime :sent_at
    end
    
  end
end
