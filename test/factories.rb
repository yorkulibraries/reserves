# frozen_string_literal: true

require 'faker'
## COMMON METHODS

FactoryGirl.define do
  sequence(:random_name) { |n| "#{Faker::Name.name} #{n}" }
  sequence(:random_string) { |_n| Faker::Lorem.sentence }
  sequence(:random_email) { |n| "#{n}_#{Faker::Internet.email}" }
  sequence(:random_username) { |n| "#{Faker::Internet.user_name}_#{n}" }
end
