require 'application_system_test_case'
require 'helpers/system_test_helper'
require 'devise/test/integration_helpers'

class SearchSystemTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include SystemTestHelper

  setup do
    @admin_user = create(:user, admin: true, role: User::MANAGER_ROLE)
    #@course_one = create(:course)
    @course_two = create(:course)

    @course_one = create(:course, code: '2013_GL_ECON_S1_2500__3_A')

    @request_one = create(:request, course: @course_one)
    @request_two = create(:request, course: @course_two)

    @items_one = create(:item, request: @request_one)
    @items_two = create(:item, request: @request_two)

    Course.reindex
    Request.reindex
    Item.reindex
  end

  should "be able to search" do 
    login_as(@admin_user)
    visit root_url

    within("form[role='search']") do
      fill_in 'q', with: 'search query'
      find('input[name="q"]').send_keys(:enter)
    end

    assert_text 'Search Results'

  end

  should "search all" do 
    Course.reindex
    login_as(@admin_user)
    visit root_url

    within("form[role='search']") do
      fill_in 'q', with: @course_one.name
      find('input[name="q"]').send_keys(:enter)
    end

    assert_text 'Search Results'

    assert_selector "tbody tr", text: @course_one.name
  end

  should "search item" do 
    login_as(@admin_user)
    visit root_url
  
    within("form.me-3") do
      fill_in 'q', with: @items_one.title
      find('input[name="q"]').send_keys(:enter)  
    end
  
    within("div.content form[action='/search']") do
      select 'Item', from: 'search_type'   
      find('input[name="q"]').send_keys(:enter) 
    end
  
    assert_text 'Search Results'  
    assert_selector "tbody tr", text: @course_one.name 

    click_link @course_one.name

    assert_selector "h3", text: @items_one.title
  end  

  should "search course" do 
    Course.reindex
    login_as(@admin_user)
    visit root_url

    #find("a[name='search button']").click

    within("form.me-3") do
      fill_in 'q', with: @course_one.name
      find('input[name="q"]').send_keys(:enter)
    end

    within("div.content form[action='/search']") do
      select 'Course', from: 'search_type'
      find('input[name="q"]').send_keys(:enter)
    end

    assert_text 'Search Results'

    assert_selector "tbody tr", text: @course_one.name

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