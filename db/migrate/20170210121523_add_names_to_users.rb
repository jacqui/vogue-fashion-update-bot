class AddNamesToUsers < ActiveRecord::Migration[5.0]
  def change
    change_table :users do |t|
      t.string :first_name
      t.string :last_name 
      t.string :gender 
      t.string :locale 
      t.string :timezone 
    end
  end
end
