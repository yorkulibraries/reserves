class AddAcquisitionEmailPerLocationToLocations < ActiveRecord::Migration[5.1]
  def change
    add_column :locations, :acquisitions_email, :string
  end
end
