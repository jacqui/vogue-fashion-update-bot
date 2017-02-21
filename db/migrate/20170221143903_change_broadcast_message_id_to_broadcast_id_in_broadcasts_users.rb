class ChangeBroadcastMessageIdToBroadcastIdInBroadcastsUsers < ActiveRecord::Migration[5.0]
  def change
    rename_column :broadcasts_users, :broadcast_message_id, :broadcast_id
  end
end
