class AddAlmaInstructorIdToCourses < ActiveRecord::Migration[7.0]
  def change
    add_column :courses, :alma_instructor_id, :string
  end
end
