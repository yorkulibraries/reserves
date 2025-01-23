# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'
require 'devise/test/integration_helpers' # Add this line

class AcquisitionRequestTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers # Include the Devise helpers
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @admin_user = create(:user, admin: true, role: User::MANAGER_ROLE)
    @user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)
    @request_open = FactoryGirl.create(:request, requester: @user)
    @item_open = FactoryGirl.create(:item, request: @request_open)
  end

  test 'Create acquisition request on item in request' do
    login_as(@admin_user)
    visit root_url

    click_link @request_open.course.name

    # Click on the "Acquisition Requests" dropdown button for the "Beans" item
    find("#item_#{@item_open.id} .acquisition_request .dropdown-toggle").click

    # Now click on the "New Request" link inside the dropdown
    find("#item_#{@item_open.id} .acquisition_request .dropdown-menu li a", text: "New Request").click

    assert_selector('.modal', visible: true, wait: 5)

    select('New Copy Required', from: 'acquisition_request_acquisition_reason')
    fill_in "acquisition_request_acquisition_notes", with: 'Test Acquisition Note'
    click_button 'Create Acquisition Request'

    # Click on the "Acquisition Requests" dropdown button for the "Beans" item
    find("#item_#{@item_open.id} .acquisition_request .dropdown-toggle").click

    assert_text "By #{@admin_user.name.split(" ").first}"
  end

  test 'Send Acquisition Email' do
    login_as(@admin_user)
    visit root_url

    click_link @request_open.course.name

    # Click on the "Acquisition Requests" dropdown button for the "Beans" item
    find("#item_#{@item_open.id} .acquisition_request .dropdown-toggle").click

    # Now click on the "New Request" link inside the dropdown
    find("#item_#{@item_open.id} .acquisition_request .dropdown-menu li a", text: "New Request").click

    assert_selector('.modal', visible: true, wait: 5)

    select('New Copy Required', from: 'acquisition_request_acquisition_reason')
    fill_in "acquisition_request_acquisition_notes", with: 'Test Acquisition Note'
    click_button 'Create Acquisition Request'

    # Click on the "Acquisition Requests" dropdown button for the "Beans" item
    find("#item_#{@item_open.id} .acquisition_request .dropdown-toggle").click

    assert_text "By #{@admin_user.name.split(" ").first}"

    click_link "By #{@admin_user.name.split(" ").first}"

    click_button 'Send Request Details'

    accept_alert

    assert_text 'Sent request to Acquisitions department'
  end

  test 'Acquiring Item' do
    login_as(@admin_user)
    visit root_url

    click_link @request_open.course.name

    # Click on the "Acquisition Requests" dropdown button for the "Beans" item
    find("#item_#{@item_open.id} .acquisition_request .dropdown-toggle").click

    # Now click on the "New Request" link inside the dropdown
    find("#item_#{@item_open.id} .acquisition_request .dropdown-menu li a", text: "New Request").click

    assert_selector('.modal', visible: true, wait: 5)

    select('New Copy Required', from: 'acquisition_request_acquisition_reason')
    fill_in "acquisition_request_acquisition_notes", with: 'Test Acquisition Note'
    click_button 'Create Acquisition Request'

    # Click on the "Acquisition Requests" dropdown button for the "Beans" item
    find("#item_#{@item_open.id} .acquisition_request .dropdown-toggle").click

    assert_text "By #{@admin_user.name.split(" ").first}"

    click_link "By #{@admin_user.name.split(" ").first}"

    select('Publisher', from: 'acquisition_request_acquisition_source_type')
    fill_in "acquisition_request_acquisition_source_name", with: 'Test Source'
    click_button "Item Acquired"

    accept_alert

    assert_text 'Changed status to acquired'
  end

end

########################################
## For Debugging and building tests ##
# page.driver.browser.manage.window.resize_to(1920, 2500)
# save_screenshot()
## HTML Save
# File.open("tmp/test-screenshots/error.html", "w") { |file| file.write(page.html) }
# save_page()
########################################
