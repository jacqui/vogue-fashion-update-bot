class CreateSentMessages < ActiveRecord::Migration[5.0]
  def change
    create_table :sent_messages do |t|
      t.string :type
      t.integer :brand_id
      t.integer :user_id
      t.integer :article_id
      t.integer :show_id
      t.datetime :sent_at
      t.text :text

      t.timestamps
    end
  end
end
