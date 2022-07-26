class AddArchiveFieldsToRequests < ActiveRecord::Migration
  def change
    add_column :requests, :archived_at, :datetime
    add_column :requests, :archived_by_id, :integer
  end
end
