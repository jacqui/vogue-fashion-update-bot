class CreateJoinTableOnUsersAndMessages < ActiveRecord::Migration[5.0]
  def change
    create_join_table :users, :broadcast_messages
  end
end
