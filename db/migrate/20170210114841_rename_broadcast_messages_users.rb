class RenameBroadcastMessagesUsers < ActiveRecord::Migration[5.0]
  def change
    rename_table :broadcast_messages_users, :broadcasts_users
  end
end
