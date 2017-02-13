class CreateSubscriptions < ActiveRecord::Migration[5.0]
  def change
    create_table :subscriptions do |t|
      t.belongs_to :user, index: true
      t.belongs_to :brand, index: true
      t.datetime :signed_up_at
      t.timestamps
    end
  end
end
