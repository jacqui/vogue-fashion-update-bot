class CreateBrands < ActiveRecord::Migration[5.0]
  def change
    create_table :brands do |t|
      t.string :title
      t.string :slug
      t.string :uid

      t.timestamps
    end
  end
end
