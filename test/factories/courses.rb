# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  sequence(:course_number_seq) { |n| 1000 + n }
  factory :course do
    name { generate(:random_string) }
    course_number { generate(:course_number_seq) }
    student_count { %w[10 20 30].sample }
    instructor FactoryGirl.generate(:random_name)
    year { ('2013'..'2099').to_a.sample }
    faculty { %w[GL SC LW AP].sample }
    subject { %w[ECON MATH COSC BIOL HIST].sample  }
    term { %w[F W FW Y S SU S1 S2].sample }
    section { ('A'..'Z').to_a.sample }
    credits { %w[3 6 9].sample }
    created_by_id 1
  end
end