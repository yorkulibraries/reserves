# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'
require 'devise/test/integration_helpers' # Add this line

class DashboardTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers # Include the Devise helpers
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @admin_user = create(:user, admin: true, role: User::MANAGER_ROLE)
    @user = FactoryGirl.create(:user, role: User::MANAGER_ROLE)

    @request_open = FactoryGirl.create(:request, requester: @user)
    @request_incomplete = FactoryGirl.create(:request, status: Request::INCOMPLETE, requester: @user)
    @request_inprogress = FactoryGirl.create(:request, status: Request::INPROGRESS, requester: @user)
    @request_completed = FactoryGirl.create(:request, status: Request::COMPLETED, requester: @user)
    @request_removed = FactoryGirl.create(:request, status: Request::REMOVED, requester: @user)
    @request_cancelled = FactoryGirl.create(:request, status: Request::CANCELLED, requester: @user)
    # @request_expiring = FactoryGirl.create(:request, 
    # reserve_end_date: Time.now + Setting.request_expiry_notice_interval.to_i.days - 1.day, 
    # status: Request::COMPLETED
    #)
  end

  test 'Dashboard landing page for instructor' do
    login_as(@user)
    visit root_url

    assert_selector 'h1', text: "My Requests"
  end

  test 'Dashboard for admin user' do
    login_as(@admin_user)
    visit root_url

    assert_selector 'h1', text: 'Dashboard'
  end

  # test 'My requests for admin user' do
  #   @request1 = FactoryGirl.create(:request, requester: @admin_user)
  #   @request3 = FactoryGirl.create(:request, requester: @admin_user)
  #   @request2 = FactoryGirl.create(:request, status: Request::INCOMPLETE, requester: @admin_user)
    
  #   login_as(@admin_user)
  #   visit root_url

  #   assert_selector 'h1', text: 'Dashboard'
  #   click_link 'My Requests'
  #   click_link 'Current Requests'
    
  #   incomplete_requests_count = page.all(:xpath, "//tr[td[contains(text(), 'INCOMPLETE')]]/following-sibling::tr[td[not(contains(@class, 'status'))]]").count

  #   open_requests_count = page.all(:xpath, "//tr[td[contains(text(), 'OPEN')]]/following-sibling::tr[td[not(contains(@class, 'status'))]]").count

  #   assert_equal 1, incomplete_requests_count, "Expected 1 incomplete request, found #{incomplete_requests_count}"
  #   assert_equal 2, open_requests_count, "Expected 2 open requests, found #{open_requests_count}"



  # end

  test "Default 'All locations' filter on dashboard" do
    login_as(@admin_user)
    visit root_url

    assert_selector('.btn-group-sm .btn-primary.dropdown-toggle', text: 'All Locations')

  end

  test "Filter location" do
    @location = FactoryGirl.create(:location, name: 'Filter location')
    @request_filter = FactoryGirl.create(:request, requester: @user, reserve_location: @location)
    
    login_as(@admin_user)
    visit root_url

    within(all('.btn-group', text: 'All Locations')[1]) do
      find('.dropdown-toggle').click
    end

    click_link 'Filter location'

    rows_count = page.all('tbody tr.click_redirect').count

    assert_equal 1, rows_count
  end

  should "show only show is_reserves_staff in the assigned_to list" do 
    @reserves_staff = create_list(:user, 3, admin:true, is_reserves_staff: true, role: User::MANAGER_ROLE)
    @non_reserves_staff = create_list(:user, 4, admin:true, is_reserves_staff: false, role: User::MANAGER_ROLE)

    login_as(@admin_user)
    visit root_url

    within all('.btn-group.pull-right .btn-group-sm').first do
      find('.dropdown-toggle', text: 'Assigned to:').click
    end

    dropdown_items = all('.dropdown-menu li a') # Get all items in the dropdown

    # Ensure the correct number of users appear. The minus -2 is Any and Nobody of the list.
    assert_equal @reserves_staff.count, dropdown_items.count - 2, "Dropdown list contains incorrect users"
  
    # Ensure only correct users appear
    @reserves_staff.each do |user|
      assert_text user.name
    end
  
    @non_reserves_staff.each do |user|
      refute_text user.name
    end

  end

  test 'Filter assigned to' do
    @user_assign = FactoryGirl.create(:user, admin: true, role: User::MANAGER_ROLE, name: 'Filter User', is_reserves_staff: true)
    @request_filter = FactoryGirl.create(:request, assigned_to: @user_assign, requester: @user_assign )
    @request_filter2 = FactoryGirl.create(:request, assigned_to: @user_assign, requester: @user_assign)
    login_as(@admin_user)
    visit root_url

    within all('.btn-group.pull-right .btn-group-sm').first do
      find('.dropdown-toggle', text: 'Assigned to:').click
    end

    click_link 'Filter User'

    rows_count = page.all('tbody tr.click_redirect').count

    assert_equal 2, rows_count
  end

  test 'Correct amount of requests as admin' do
    login_as(@admin_user)
    visit root_url

    rows_count = page.all('tbody tr.click_redirect').count

    assert_text 'Open Requests'
    
    assert_equal 1, rows_count

    click_link 'Incomplete'

    rows_count = page.all('tbody tr.click_redirect').count

    assert_text 'Incomplete Requests'

    assert_equal 1, rows_count

    click_link 'In Progress'

    rows_count = page.all('tbody tr.click_redirect').count

    assert_text 'In progress Requests'

    assert_equal 1, rows_count

    click_link 'Completed'

    rows_count = page.all('tbody tr.click_redirect').count

    assert_text 'Completed Requests'

    assert_equal 1, rows_count

    find('#more_requests').click

    find("a[href='/?which=removed']").click

    rows_count = page.all('tbody tr.click_redirect').count

    assert_text 'Removed Requests'
    assert_equal 1, rows_count

    find('a#more_requests').click

    find('ul.dropdown-menu a', text: 'Cancelled').click

    rows_count = page.all('tbody tr.click_redirect').count

    assert_text 'Cancelled Requests'
    assert_equal 1, rows_count

  end

  test 'Delete incomplete request as admin' do
    @request_incomplete = FactoryGirl.create(:request, status: Request::INCOMPLETE, requester: @admin_user)
    @request_incomplete2 = FactoryGirl.create(:request, status: Request::INCOMPLETE, requester: @admin_user)

    login_as(@admin_user)
    visit root_url

    click_link 'My Requests'
    click_link 'Current Requests'

    within "table.table.table-bordered.request tbody" do
      page.accept_confirm do
        first(:xpath, ".//tr[td[contains(., 'INCOMPLETE')]]/following-sibling::tr")
          .find("a.btn.btn-xs.btn-danger", text: "Delete")
          .click
      end
    end

    assert_text 'Listing requests'

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
