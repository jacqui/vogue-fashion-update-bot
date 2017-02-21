class AddTemplateSupportToBroadcasts < ActiveRecord::Migration[5.0]
  def change
    add_column :broadcasts, :title, :string
    add_column :broadcasts, :image_url, :string
    add_column :broadcasts, :button_text, :string
    add_column :broadcasts, :link, :string
    add_column :broadcasts, :template, :string
  end
end
