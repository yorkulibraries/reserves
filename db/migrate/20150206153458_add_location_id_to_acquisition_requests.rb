class AddLocationIdToAcquisitionRequests < ActiveRecord::Migration
  def change
    add_column :acquisition_requests, :location_id, :integer
  end
end
