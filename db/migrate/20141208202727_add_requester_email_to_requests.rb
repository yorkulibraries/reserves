class AddRequesterEmailToRequests < ActiveRecord::Migration
  def change
    add_column :requests, :requester_email, :string
  end
end
