class ChangeArticlesImageUid < ActiveRecord::Migration[5.0]
  def change
    change_table :articles do |t|
      t.string :image_uid
    end
    change_table :shows do |t|
      t.string :image_uid
    end
  end
end
