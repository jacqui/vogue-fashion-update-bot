class AddImageUrlToShows < ActiveRecord::Migration[5.0]
  def change
    add_column :shows, :image_url, :string
  end
end
