# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class RequestsTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    api_keys = YAML.load_file(Rails.root.join('config', 'api_keys.yml'))


    @alma_api_key = api_keys[Rails.env][:alma_api_key]
    @alma_region = api_keys[Rails.env][:alma_region]
    @primo_api_key = api_keys[Rails.env][:primo_api_key]
    @primo_inst = api_keys[Rails.env][:primo_inst]
    @primo_vid = api_keys[Rails.env][:primo_vid]
    @primo_region = api_keys[Rails.env][:primo_region]
    @primo_scope = api_keys[Rails.env][:primo_scope]
    @worldcat_api_key = api_keys[Rails.env][:worldcat_api_key]

    @loan_period = FactoryGirl.create(:loan_period)
    @request = FactoryGirl.create(:request, status: Request::INCOMPLETE)
    @request1 = FactoryGirl.create(:request, status: Request::OPEN)
    @request2 = FactoryGirl.create(:request, status: Request::COMPLETED)
  end

  test 'Complete step 1 of a request' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select Course::ACADEMIC_YEARS_FULL.first[0], from: 'request_course_attributes_year'
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

  test 'Set status of request to Incomplete' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select Course::ACADEMIC_YEARS_FULL.first[0], from: 'request_course_attributes_year'
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

    first(:link, "Save this request for later").click

    assert_selector 'h1', text: "Request #4"
    assert_selector '.label.label-default', text: "Incomplete"

    visit root_url
    click_link "Incomplete"
    find('button .fa-home').click
    click_link "All Locations"
    assert_selector 'a', text: "Course Title"
  end

  test 'Set status of request to Open' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select Course::ACADEMIC_YEARS_FULL.first[0], from: 'request_course_attributes_year'
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

    assert_selector 'h1', text: "Request #4"
    assert_selector '.label.label-default', text: "Open"

    visit root_url
    find('button .fa-home').click
    click_link "All Locations"
    assert_selector 'a', text: "Course Title"
  end

  test 'Set status of request to In Progress' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select Course::ACADEMIC_YEARS_FULL.first[0], from: 'request_course_attributes_year'
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

    assert_selector 'h1', text: "Request #4"
    assert_selector '.label.label-default', text: "Open"

    click_link "Start"
    page.accept_alert

    assert_selector '.label.label-default', text: "In progress"
  end

  test 'Set status of request to Completed' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select Course::ACADEMIC_YEARS_FULL.first[0], from: 'request_course_attributes_year'
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

    assert_selector 'h1', text: "Request #4"
    assert_selector '.label.label-default', text: "Open"

    click_link "Start"
    page.accept_alert

    assert_selector '.label.label-default', text: "In progress"

    assert_selector 'span.label.label-default.item-status', text: 'Not ready'
    first('.fa.fa-check.bigger').click

    fill_in 'item_ils_barcode', with: 14.times.map { rand(10) }.join
    click_button "Save Barcode"

    assert_selector 'span.label.label-default.item-status', text: 'Ready'

    click_link "Complete"
    page.accept_alert

    assert_selector '.label.label-default', text: "Completed"
    assert_selector '.alert-success', text: "Status changed to completed"

    visit root_url
    click_link "Completed"
    find('button .fa-home').click
    click_link "All Locations"
    assert_selector 'a', text: "Course Title"
  end

  test 'Reopen a completed request' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "Completed"
    find('button .fa-home').click
    click_link "All Locations"
    click_link @request2.course.name

    click_link "Add More Items / Re Open"
    page.accept_alert

    assert_selector '.label.label-default', text: "Open"
    assert_selector '.alert-success', text: "Status changed to open and request has been unassigned"
  end

  test 'Attempt to create request with empty form' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    click_button "Continue to Step Two"

    assert_selector '.alert-info', text: "Course couldn't be saved. Please check the details."
  end

  test 'Change owner in request' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)

    user1 = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    user2 = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    user3 = FactoryGirl.create(:user, role: User::MANAGER_ROLE)

    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    visit root_url

    find('button .fa-home').click
    click_link "All Locations"

    click_link @request1.course.name

    click_button "Change Owner"
    select user3.name, from: 'requester_name'
    click_button "Change Owner"

    assert_selector 'a', text: user3.name
  end

  test 'Create request with incorrect email format' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    click_link "New Request"

    fill_in 'request_course_attributes_name', with: 'Course Title'
    select Course::ACADEMIC_YEARS_FULL.first[0], from: 'request_course_attributes_year'
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
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)

    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    find('a.dropdown-toggle[aria-label="Settings"]').click
    click_link "Primo and Alma"
    fill_in 'setting_primo_apikey', with: @primo_api_key
    fill_in 'setting_primo_inst', with: @primo_inst
    fill_in 'setting_primo_vid', with: @primo_vid
    fill_in 'setting_primo_region', with: @primo_region
    fill_in 'setting_primo_scope', with: @primo_scope
    fill_in 'setting_alma_apikey', with: @alma_api_key
    fill_in 'setting_alma_region', with: @alma_region
    click_button "Save Primo and Alma Settings"

    visit root_url

    find('button .fa-home').click
    click_link "All Locations"

    click_link @request1.course.name

    click_link "Book"

    find('input[name="q"]').set('To Kill a Mockingbird')
    click_button "Go!"
    assert_selector('div.panel-heading', text: 'Search Results:')
    first('.usethis').click
    isbn_value = find('#item_isbn').value
    assert_match(/^\d+$/, find('#item_isbn').value, "The ISBN field contains symbols.")
    select @loan_period.duration, from: 'item_loan_period'
    click_button "Create Item"


    assert_selector 'h1', text: "Request #2"
    assert_selector 'h3', text: /to kill a mockingbird/i
  end

  test 'Convert request item to status ready' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)

    visit root_url
    assert_selector '.alert-success', text: "Logged in!"

    find('button .fa-home').click
    click_link "All Locations"

    click_link @request1.course.name

    click_link "Ebook"

    fill_in 'item_title', with: 'Ebook Title'
    fill_in 'item_author', with: 'Ebook Author'
    fill_in 'item_publisher', with: 'Ebook Publisher'
    click_button "Create Item"

    assert_selector 'h3', text: "Ebook Title"

    assert_selector 'span.label.label-default.item-status', text: 'Not ready'
    first('.fa.fa-check.bigger').click

    fill_in 'item_ils_barcode', with: 14.times.map { rand(10) }.join
    click_button "Save Barcode"

    assert_selector 'span.label.label-default.item-status', text: 'Ready'

  end

  # test 'TEST TEST TEST' do
  #   user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
  #   login_as(user)
  #   request = FactoryGirl.create(:request, status: Request::INCOMPLETE)
  #   visit root_url
  #   assert_selector 'span.label.label-default.item_ready.item-status', text: 'Ready'
  # end
end
