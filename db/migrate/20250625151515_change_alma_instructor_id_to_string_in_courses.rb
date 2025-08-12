class ChangeAlmaInstructorIdToStringInCourses < ActiveRecord::Migration[7.0]
  def change
    change_column :courses, :alma_instructor_id, :string
  end
end
