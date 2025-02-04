# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :item do
    association :request, factory: :request

    metadata_source Item::METADATA_MANUAL
    status Item::STATUS_NOT_READY
    loan_period '2 Hours'

    title { generate(:random_string) }
    author { generate(:random_name) }
    isbn { Faker::Number.number(digits: 13) }
    callnumber { Faker::Alphanumeric.alphanumeric(number: 10).upcase }
    description { Faker::Lorem.paragraph }
    publication_date { Faker::Number.between(from: 1900, to: 2025).to_s }
    publisher { Faker::Book.publisher }
    item_type Item::TYPE_BOOK
    edition { "#{Faker::Number.between(from: 1, to: 20)}th" }
    format Item::FORMAT_BOOK
    map_index_num nil
    url nil
    copyright_options nil
    other_copyright_options nil

    ils_barcode ''

    issue nil
    journal_title nil
    volume nil
    page_number nil

    provided_by_requestor false
  end
end
