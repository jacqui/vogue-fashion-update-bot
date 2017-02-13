class CreateConversations < ActiveRecord::Migration[5.0]
  def change
    create_table :conversations do |t|
      t.references :user, foreign_key: true
      t.datetime :started_at
      t.datetime :last_message_sent_at
      t.text :transcript

      t.timestamps
    end
  end
end
