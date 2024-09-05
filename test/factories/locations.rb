# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :location do
    name { FactoryGirl.generate(:random_name) }
    contact_email { FactoryGirl.generate(:random_email) }
    contact_phone '416-222-3333'
    address '123 Fake Street'
    disallowed_item_types nil
    acquisitions_email nil
    # association :department, factory: :department
  end
end
