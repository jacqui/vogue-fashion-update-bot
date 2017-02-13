class CreateShows < ActiveRecord::Migration[5.0]
  def change
    create_table :shows do |t|
      t.string :title
      t.string :uid
      t.datetime :published_at
      t.datetime :date_time
      t.string :slug
      t.text :review

      t.timestamps
    end
  end
end
