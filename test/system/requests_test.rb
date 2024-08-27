# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class RequestsTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do

  end

  test 'Create a request - Step 1' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select "2023/2024", from: 'request_course_attributes_year'
    select "AP", from: 'request_course_attributes_faculty'
    select "ACTG", from: 'request_course_attributes_subject'
    fill_in 'request_course_attributes_course_id', with: '1234'
    select "F", from: 'request_course_attributes_term'
    select "1", from: 'request_course_attributes_credits'
    select "A", from: 'request_course_attributes_section'
    fill_in 'request_course_attributes_instructor', with: 'Instructor'
    fill_in 'request_course_attributes_student_count', with: '1'
    find('#request_reserve_location_id').find("option[value='1']").select_option
    click_button "Continue to Step Two"
    assert_selector '.alert-success', text: "Proceeding to Step 2."
  end

  test 'Create a request - Step 2' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select "2023/2024", from: 'request_course_attributes_year'
    select "AP", from: 'request_course_attributes_faculty'
    select "ACTG", from: 'request_course_attributes_subject'
    fill_in 'request_course_attributes_course_id', with: '1234'
    select "F", from: 'request_course_attributes_term'
    select "1", from: 'request_course_attributes_credits'
    select "A", from: 'request_course_attributes_section'
    fill_in 'request_course_attributes_instructor', with: 'Instructor'
    fill_in 'request_course_attributes_student_count', with: '1'
    find('#request_reserve_location_id').find("option[value='1']").select_option
    click_button "Continue to Step Two"


    assert_selector '.alert-success', text: "Proceeding to Step 2."

    click_link "Ebook"

    fill_in 'item_title', with: 'Ebook Title'
    fill_in 'item_author', with: 'Ebook Author'
    fill_in 'item_publisher', with: 'Ebook Publisher'
    click_button "Create Item"

    assert_selector 'h3', text: "Ebook Title"

    click_link "I am done, submit this request"

    assert_selector 'h1', text: "Request #1"
  end

  # test 'Create request with empty form' do
  #   user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
  #   visit root_url
  #   assert_selector '.alert-success', text: "Logged in!"

  #   click_link "New Request"

  #   click_button "Continue to Step Two"


  # end

  test 'Change owner in request' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)

    user1 = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    user2 = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    user3 = FactoryGirl.create(:user, role: User::MANAGER_ROLE)

    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select "2023/2024", from: 'request_course_attributes_year'
    select "AP", from: 'request_course_attributes_faculty'
    select "ACTG", from: 'request_course_attributes_subject'
    fill_in 'request_course_attributes_course_id', with: '1234'
    select "F", from: 'request_course_attributes_term'
    select "1", from: 'request_course_attributes_credits'
    select "A", from: 'request_course_attributes_section'
    fill_in 'request_course_attributes_instructor', with: 'Instructor'
    fill_in 'request_course_attributes_student_count', with: '1'
    find('#request_reserve_location_id').find("option[value='1']").select_option
    click_button "Continue to Step Two"


    assert_selector '.alert-success', text: "Proceeding to Step 2."

    click_link "Ebook"

    fill_in 'item_title', with: 'Ebook Title'
    fill_in 'item_author', with: 'Ebook Author'
    fill_in 'item_publisher', with: 'Ebook Publisher'
    click_button "Create Item"

    click_link "I am done, submit this request"

    click_button "Change Owner"
    select user3.name, from: 'requester_name'
    click_button "Change Owner"
  end

  test 'Create request with incorrect email format' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select "2023/2024", from: 'request_course_attributes_year'
    select "AP", from: 'request_course_attributes_faculty'
    select "ACTG", from: 'request_course_attributes_subject'
    fill_in 'request_course_attributes_course_id', with: '1234'
    select "F", from: 'request_course_attributes_term'
    select "1", from: 'request_course_attributes_credits'
    select "A", from: 'request_course_attributes_section'
    fill_in 'request_course_attributes_instructor', with: 'Instructor'
    fill_in 'request_course_attributes_student_count', with: '1'
    find('#request_reserve_location_id').find("option[value='1']").select_option
    fill_in 'request_requester_email', with: 'emailiswrong'
    click_button "Continue to Step Two"
    assert_selector 'span.help-block.has-error', text: 'is invalid'
    assert_selector 'div.request_requester_email.has-error'
  end

  test 'Adding a book to request with ISBN' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select "2023/2024", from: 'request_course_attributes_year'
    select "AP", from: 'request_course_attributes_faculty'
    select "ACTG", from: 'request_course_attributes_subject'
    fill_in 'request_course_attributes_course_id', with: '1234'
    select "F", from: 'request_course_attributes_term'
    select "1", from: 'request_course_attributes_credits'
    select "A", from: 'request_course_attributes_section'
    fill_in 'request_course_attributes_instructor', with: 'Instructor'
    fill_in 'request_course_attributes_student_count', with: '1'
    find('#request_reserve_location_id').find("option[value='1']").select_option
    fill_in 'request_requester_email', with: 'emailiswrong'
    click_button "Continue to Step Two"
    assert_selector 'span.help-block.has-error', text: 'is invalid'
    assert_selector 'div.request_requester_email.has-error'
  end
end
