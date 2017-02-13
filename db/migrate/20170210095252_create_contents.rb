class CreateContents < ActiveRecord::Migration[5.0]
  def change
    create_table :contents do |t|
      t.string :title
      t.string :label
      t.text :body

      t.timestamps
    end
  end
end
