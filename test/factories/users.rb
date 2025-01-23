# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
    name 'Jeremy Clarkson'
    sequence(:email, 1000) { |n| "e#{n}@yorku.ca" }
    phone '124'
    user_type User::FACULTY
    role User::INSTRUCTOR_ROLE
    department 'History'
    office 'Some where'
    sequence(:uid, 1000) { |n| "uid#{n}" }
    sequence(:username, 1000) { |n| "username#{n}" }
    active true
    admin false

    trait :admin do
      after(:create) do |user|
        user.add_role(:admin)
      end
    end

    last_login 1.day.ago
    created_by nil

    association :location, factory: :location
  end
end
