class AddSubscriptionToSentMessages < ActiveRecord::Migration[5.0]
  def change
    add_column :sent_messages, :subscription_id, :integer
    add_column :sent_messages, :push_notification, :boolean, default: false
  end
end
