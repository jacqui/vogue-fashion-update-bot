class AddMajorToShows < ActiveRecord::Migration[5.0]
  def change
    add_column :shows, :major, :boolean, default: false
  end
end
