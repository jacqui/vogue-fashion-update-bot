class AddCniEmployeeToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :cni_employee, :boolean, default: false
  end
end
