class AddSettingBccLocationToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :setting_bcc_location_on_new_item, :boolean, default: false
  end
end
