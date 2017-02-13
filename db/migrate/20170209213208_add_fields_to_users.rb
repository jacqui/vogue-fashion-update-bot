class AddFieldsToUsers < ActiveRecord::Migration[5.0]
  def change
    change_table :users do |t|
      t.datetime :last_message_sent_at
    end
  end
end
