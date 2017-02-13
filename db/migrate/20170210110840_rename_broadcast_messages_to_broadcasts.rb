class RenameBroadcastMessagesToBroadcasts < ActiveRecord::Migration[5.0]
  def change
    rename_table :broadcast_messages, :broadcasts
  end
end
