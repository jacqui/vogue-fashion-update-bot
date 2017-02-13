class RenameOrderColumn < ActiveRecord::Migration[5.0]
  def change
    change_table :questions do |t|
      t.rename :order, :sort_order
    end
    change_table :possible_answers do |t|
      t.rename :order, :sort_order
    end
    change_table :responses do |t|
      t.remove :order
    end
  end
end
