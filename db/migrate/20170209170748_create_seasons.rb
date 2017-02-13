class CreateSeasons < ActiveRecord::Migration[5.0]
  def change
    create_table :seasons do |t|
      t.string :title
      t.string :uid
      t.string :slug

      t.timestamps
    end
  end
end
