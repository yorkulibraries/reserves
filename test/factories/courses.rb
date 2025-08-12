# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  sequence(:course_id_seq) { |n| 1000 + n }
  factory :course do
    name { generate(:random_string) }
    # code "2013_GL_ECON_S1_2500__3_A"
    sequence(:code) { |n| "2025_GL_ECON_F_#{2000 + n}_3_A_#{SecureRandom.hex(2)}" }
    course_id { generate(:course_id_seq) }
    student_count 20
    instructor FactoryGirl.generate(:random_name)
    code_year { "2025" }
    section { "A" }
    created_by_id 1
    credits { 3 }
  end
end
