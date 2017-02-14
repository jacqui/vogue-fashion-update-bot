class DropImageUrlFromArticlesAndShows < ActiveRecord::Migration[5.0]
  def change
    remove_column :articles, :image_url
    remove_column :shows, :image_url
  end
end
