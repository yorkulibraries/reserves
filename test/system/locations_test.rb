#frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class LocationsTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)

    @location1 = FactoryGirl.create(:location)
    @location2 = FactoryGirl.create(:location)
    @location3 = FactoryGirl.create(:location)

    @request = FactoryGirl.create(:request, status: Request::INCOMPLETE, reserve_location: @location1, assigned_to: @user)
  end

  test 'Add a new location' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Locations"
    click_link "Add a new location"

    fill_in 'location_name', with: 'Test Location'
    fill_in 'location_contact_email', with: 'testlocation@test.com'
    fill_in 'location_contact_phone', with: '1231231234'
    fill_in 'location_address', with: '123 Test Ave'
    click_button 'Create Location'

    assert_selector '.alert-success', text: "Location was successfully created."

    assert_text 'Test Location'
  end

  test 'Edit a location' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Locations"
    find('tr', text: @location1.name).click_link('Make Changes')

    fill_in 'location_name', with: 'Test Location'
    fill_in 'location_contact_email', with: 'testlocation@test.com'
    fill_in 'location_contact_phone', with: '1231231234'
    fill_in 'location_address', with: '123 Test Ave'
    click_button 'Update Location'

    assert_selector '.alert-success', text: "Location was successfully updated."

    assert_text 'Test Location'
  end

  test 'Delete a location' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Locations"
    find('tr', text: @location1.name).click_link('Make Changes')

    click_link 'Remove this location record?'

    page.accept_alert

    assert_selector '.alert-success', text: "Location was successfully flagged as deleted and removed from the list."

    assert_no_text @location1.name
  end

  test 'Create a location with invalid email' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Locations"
    find('tr', text: @location1.name).click_link('Make Changes')

    fill_in 'location_name', with: 'Test Location'
    fill_in 'location_contact_email', with: 'testlocation'
    fill_in 'location_contact_phone', with: '1231231234'
    fill_in 'location_address', with: '123 Test Ave'
    click_button 'Update Location'

    assert_selector 'div.form-group.location_contact_email.has-error'
    assert_selector 'span.help-block.has-error', text: 'Invalid email format.'
  end

  test 'Set location with disallowed item types' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Locations"

    find('tr', text: @location1.name).click_link('Make Changes')

    check 'location_disallowed_item_types_book'
    check 'location_disallowed_item_types_ebook'
    check 'location_disallowed_item_types_multimedia'
    check 'location_disallowed_item_types_course_kit'
    click_button 'Update Location'

    click_link 'Dashboard'
    click_link 'Incomplete'
    find('button .fa-home').click
    click_link @location1.name

    click_link @request.course.name

    assert_no_selector 'a', text: "Book"
    assert_no_selector 'a', text: "Ebook"
    assert_no_selector 'a', text: "Multimedia"
    assert_no_selector 'a', text: "Course Kit"
  end

end
