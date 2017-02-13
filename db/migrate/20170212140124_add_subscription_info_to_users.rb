class AddSubscriptionInfoToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :shows_subscription, :text
    add_column :users, :top_stories_subscription, :boolean, default: false
  end
end
