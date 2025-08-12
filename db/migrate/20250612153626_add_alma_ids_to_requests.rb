class AddAlmaIdsToRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :requests, :alma_course_id, :string
    add_column :requests, :alma_reading_list_id, :string
  end
end
