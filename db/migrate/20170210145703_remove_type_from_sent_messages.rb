class RemoveTypeFromSentMessages < ActiveRecord::Migration[5.0]
  def change
    remove_column :sent_messages, :type
  end
end
