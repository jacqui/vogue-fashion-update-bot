class AddInternalOnlyToBroadcasts < ActiveRecord::Migration[5.0]
  def change
    add_column :broadcasts, :internal_only, :boolean, default: false
  end
end
