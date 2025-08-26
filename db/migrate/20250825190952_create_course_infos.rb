class CreateCourseInfos < ActiveRecord::Migration[7.0]
  def change
    create_table :course_infos do |t|
      t.string :faculty
      t.string :faculty_abrev
      t.string :faculty_short
      t.string :period_faculty
      t.string :subject_abrev
      t.string :subject_abrev2
      t.string :subject, null: false
      t.string :academic_year
      t.string :study_session
      t.string :crs_id
      t.text :course_title, null: false
      t.text :course_title1
      t.string :course_number, null: false
      t.string :year_level
      t.integer :credit
      t.string :section
      t.string :instructor_name

      t.timestamps
    end
  end
end
