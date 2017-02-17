class AddUnmatchedBrandToMessages < ActiveRecord::Migration[5.0]
  def change
    add_column :messages, :unmatched_brand, :boolean, default: false
  end
end
