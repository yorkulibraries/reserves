class AddRolloverParentIdToRequests < ActiveRecord::Migration
  def change
    add_column :requests, :rollover_parent_id, :integer
    add_column :requests, :rolledover_at, :datetime
  end
end
