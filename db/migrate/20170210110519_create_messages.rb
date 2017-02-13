class CreateMessages < ActiveRecord::Migration[5.0]
  def change
    create_table :messages do |t|
      t.string :mid
      t.string :senderid
      t.integer :seq
      t.datetime :sent_at
      t.text :text
      t.text :attachments
      t.text :quick_reply

      t.timestamps
    end
  end
end
