class CreateCourses < ActiveRecord::Migration
  def change
    create_table :courses do |t|
      t.string :name
      t.string :code
      t.integer :student_count
      t.string :instructor
      t.integer :created_by_id

      t.timestamps
    end
  end
end
