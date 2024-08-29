# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl
require 'date'

FactoryGirl.define do
  factory :request do
    requested_date '2025-04-17'
    reserve_start_date 1.month.ago.to_date.strftime('%Y-%m-%d')
    reserve_end_date 2.months.from_now.to_date.strftime('%Y-%m-%d')
    status Request::OPEN
    requester_email { Faker::Internet.email }

    association :requester, factory: :user
    association :reserve_location, factory: :location
    association :course, factory: :course
    association :assigned_to, factory: :user
  end
end
