# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :location do
    sequence(:name) { |n| "Location #{n}" }
    contact_email { Faker::Internet.email }
    contact_phone { Faker::PhoneNumber.phone_number }
    address { "123 #{Faker::Address.street_name}" }
    disallowed_item_types nil
    acquisitions_email nil
    # association :department, factory: :department
  end
end
