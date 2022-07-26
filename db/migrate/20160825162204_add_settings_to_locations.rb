class AddSettingsToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :setting_bcc_request_status_change, :boolean, default: false
  end
end
