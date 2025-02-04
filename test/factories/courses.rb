# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :course do
    name FactoryGirl.generate(:random_string)
    # code "2013_GL_ECON_S1_2500__3_A"
    sequence(:code) { |n| "2013_GL_ECON_S1_200#{n}__3_A" }
    student_count 20
    instructor FactoryGirl.generate(:random_name)
    created_by_id 1
  end
end
