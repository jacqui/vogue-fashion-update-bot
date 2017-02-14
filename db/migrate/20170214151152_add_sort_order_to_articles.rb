class AddSortOrderToArticles < ActiveRecord::Migration[5.0]
  def change
    add_column :articles, :sort_order, :integer
    add_column :articles, :display_date, :datetime
  end
end
