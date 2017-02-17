class UserSubscriptionFields < ActiveRecord::Migration[5.0]
  def change
    change_table :users do |t|
      t.remove :top_stories_subscription
      t.remove :shows_subscription

      t.boolean :subscribe_top_stories, default: false
      t.boolean :subscribe_all_shows, default: false
      t.boolean :subscribe_major_shows, default: false
    end
  end
end
