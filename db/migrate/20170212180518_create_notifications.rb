class CreateNotifications < ActiveRecord::Migration[5.0]
  def change
    create_table :notifications do |t|
      t.references :user, foreign_key: true
      t.references :article, foreign_key: true
      t.references :brand, foreign_key: true
      t.datetime :sent_at
      t.boolean :sent
      t.references :show, foreign_key: true

      t.timestamps
    end
  end
end
