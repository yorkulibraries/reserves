class AddUnivIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :univ_id, :string
    add_index :users, :univ_id, unique: true
  end
end
