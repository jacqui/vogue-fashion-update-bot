class CreateLocations < ActiveRecord::Migration[5.0]
  def change
    create_table :locations do |t|
      t.string :title
      t.string :uid
      t.string :slug

      t.timestamps
    end
  end
end
