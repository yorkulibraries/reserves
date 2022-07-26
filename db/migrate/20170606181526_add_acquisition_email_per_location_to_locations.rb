class AddAcquisitionEmailPerLocationToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :acquisitions_email, :string
  end
end
