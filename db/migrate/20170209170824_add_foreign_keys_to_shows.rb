class AddForeignKeysToShows < ActiveRecord::Migration[5.0]
  def change
    add_column :shows, :location_id, :integer
    add_column :shows, :brand_id, :integer
    add_column :shows, :season_id, :integer
  end
end
