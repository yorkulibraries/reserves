class AddRequesterEmailToRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :requests, :requester_email, :string
  end
end
