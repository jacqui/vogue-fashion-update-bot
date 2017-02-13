class AddTagToArticles < ActiveRecord::Migration[5.0]
  def change
    add_column :articles, :tag, :string
  end
end
