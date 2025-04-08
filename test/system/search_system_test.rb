require 'application_system_test_case'
require 'helpers/system_test_helper'
require 'devise/test/integration_helpers'

class UserSystemTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include SystemTestHelper

  setup do
    Course.reindex
    Request.reindex
    @admin_user = create(:user, admin: true, role: User::MANAGER_ROLE)
    @course_one = create(:course)
    @course_two = create(:course)

    @request_one = create(:request, course: @course_one)
    @request_two = create(:request, course: @course_two)

    @items_one = create_list(:item, 5, request: @request_one)
    @items_two = create_list(:item, 5, request: @request_two)
  end

  should "be able to search" do 
    login_as(@admin_user)
    visit root_url

    find("a[name='search button']").click

    fill_in 'q', with: 'search query'

    find('input[name="q"]').send_keys(:enter)

    assert_text 'Search Results'

  end

  should "search all" do 
    login_as(@admin_user)
    visit root_url

    find("a[name='search button']").click

    fill_in 'q', with: 'ECON'

    find('input[name="q"]').send_keys(:enter)

    assert_text 'Search Results'


    assert_selector "tbody tr", count: 2
  end

  should "search request" do 
    #item = @items_one.sample
    
    login_as(@admin_user)
    visit root_url

    find("a[name='search button']").click

    fill_in 'q', with: 'Course'

    find('input[name="q"]').send_keys(:enter)

    assert_text 'Search Results'
  end

  should "search item" do 
    item = @items_one.sample
    
    login_as(@admin_user)
    visit root_url

    find("a[name='search button']").click

    fill_in 'q', with: item.title

    find('input[name="q"]').send_keys(:enter)

    select 'Item', from: 'search_type'

    find('input[name="q"]').send_keys(:enter)

    assert_text 'Search Results'

    click_link item.request.course.name

    assert_text item.title

  end

  should "search course" do 
    
    login_as(@admin_user)
    visit root_url

    find("a[name='search button']").click

    fill_in 'q', with: @course_one.name

    find('input[name="q"]').send_keys(:enter)

    select 'Course', from: 'search_type'

    find('input[name="q"]').send_keys(:enter)

    assert_text 'Search Results'

    assert_selector "tbody tr td.course", text: @course_one.name

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