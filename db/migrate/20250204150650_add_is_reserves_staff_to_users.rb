class AddIsReservesStaffToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :is_reserves_staff, :boolean
  end
end
