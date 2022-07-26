class AddIlsLocationNameToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :ils_location_name, :string
  end
end
