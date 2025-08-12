# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'
require 'devise/test/integration_helpers' # Add this line

class RequestTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers # Include the Devise helpers
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @admin_user = create(:user, admin: true, role: User::MANAGER_ROLE)
    @user = FactoryGirl.create(:user, role: User::INSTRUCTOR_ROLE)
    FactoryGirl.create(:loan_period)

    @course = create(:course, code: '2025_GL_ECON_S1_2500__3_A')
    @course1 = create(:course, code: '2025_GL_ECON_S1_2500__3_B')

    @request_open = create(:request, requester: @user, course: @course)
    @request_completed = create(:request, status: Request::COMPLETED, requester: @user, course: @course1)

    @item_open = FactoryGirl.create(:item, request: @request_open)
    @item_completed = FactoryGirl.create(:item, request: @request_completed)
  end

  test 'Start new request' do
    login_as(@user)
    visit root_url

    click_link('New Request')

    assert_text "Submit New Request - Step One"
  end

  test 'Start request' do
    login_as(@admin_user)
    visit root_url

    click_link @request_open.course.name

    click_link 'Start'

    accept_alert

    assert_text 'Status changed to in progress'

  end

  test 'search for non-existing course' do
    login_as(@user)
    visit root_url

    click_link('New Request')

    # Search for a non-existing course
    fill_in 'request_course_id', with: 'Non-existing Course'

    # Submit the form
    click_button 'Continue to Step Two'

    # Ensure that an appropriate error message is displayed for no results
    assert_text 'No course found matching your search'
  end

  test 'Submit empty request' do
    login_as(@user)
    visit root_url

    click_link('New Request')

    assert_text "Submit New Request - Step One"

    click_button 'Continue to Step Two'

    assert_text "Submit New Request - Step One"
    assert_text "Course cannot be empty"
  end

  test 'Complete step one' do
    login_as(@user)
    visit root_url

    click_link('New Request')
    academic_year = "#{Time.current.year}/#{Time.current.year + 1}"
    fill_in 'request_course_id', with: 'ECON', wait: 5

    fill_in 'request_course_attributes_student_count', with: '1234'
    fill_in 'request_requester_email', with: 'email@test.com'
    first_option = find('#request_reserve_location_id').all('option')[1]
    select(first_option.text, from: 'request_reserve_location_id')
    
    click_button 'Continue to Step Two'

    assert_text "Submit New Request - Step Two"
  end

  test 'Complete request' do
    login_as(@user)
    visit root_url

    click_link('New Request')
    academic_year = "#{Time.current.year}/#{Time.current.year + 1}"
    fill_in 'request_course_id', with: 'ECON'
    fill_in 'request_course_attributes_student_count', with: '1234'
    fill_in 'request_requester_email', with: 'email@test.com'
    first_option = find('#request_reserve_location_id').all('option')[1]
    select(first_option.text, from: 'request_reserve_location_id')
    
    click_button 'Continue to Step Two'

    assert_text "Submit New Request - Step Two"

    click_link 'Book'

    assert_selector '#item_form', visible: true

    fill_in 'item_title', with: 'Book Title'
    fill_in 'item_author', with: 'Book Author'
    fill_in 'item_publisher', with: 'Book Publisher'
    fill_in 'item_isbn', with: '123456789'
    select('2 Hours', from: 'item_loan_period')

    click_button 'Create Item' 
    save_page

    sleep(1)
    # Ensure the modal disappears completely before proceeding
    assert_no_selector '#item_form', visible: true
    
    click_link 'I am done, submit this request'
    
    assert_text 'Request #'
    assert_text 'Open'

    click_link "Reserves"

    assert_text 'Course Title'
  end

  
  test 'Update request details' do
    # Ensure the autocomplete endpoint has data to return
    Course.reindex
  
    login_as(@user)
    visit root_url
  
    within('table.request tbody') { first('a.name').click }
    click_link 'Update Request'
    assert_text 'Make Changes To Request'
  
    field = find('#request_course_search', visible: true)
    field.click
  
    # Type slowly to guarantee key events & minLength(4) behavior
    '2025_GL_ECON'.each_char { |ch| field.send_keys(ch) }
  
    # Wait for any suggestion to appear (the wrapper is the clickable element)
    assert_selector('ul.ui-autocomplete li .ui-menu-item-wrapper', wait: 10)
  
    # Option A (most resilient): use keyboard to select the first suggestion
    field.send_keys(:arrow_down, :enter)
  
    # OR Option B (explicit match): click a specific suggestion text
    # find('ul.ui-autocomplete li .ui-menu-item-wrapper',
    #      text: '2025_GL_ECON_S1_2500__3_A', match: :first).click
  
    # Now the hidden field should be set by your select handler
    assert_field('request_course_attributes_course_id',
                 with: @course.id.to_s,
                 visible: :all)
  
    click_button 'Update Request Details'
    assert_text 'Request was successfully updated.'
  end            

  test 'Update request item' do
    login_as(@user)
    visit root_url

    within('table.request tbody') do
      first('a.name').click
    end

    first('button', text: 'Update Item').click

    #find('.btn-group button', text: 'Update Item').click

    find('.dropdown-menu a', text: 'Change Item Details').click

    assert_selector('.modal', visible: true, wait: 5)

    fill_in 'item_title', with: 'Test Update Item Title'

    fill_in 'item_author', with: 'Test Update Item Author'

    fill_in 'item_publisher', with: 'Test Update Item Publisher'

    find('input[type="submit"][value="Update Item"]').click

    assert_text 'Test Update Item Title'

    assert_text 'Test Update Item Author'

    assert_text 'Test Update Item Publisher'

  end

  test 'Remove Item from Request' do
    @item = FactoryGirl.create(:item, request: @request_open, title: "Remove This Item")
    login_as(@user)
    visit root_url

    within('tbody') do
      within(:xpath, "//tr[td[contains(text(), 'OPEN')]]/following-sibling::tr[1]") do
        click_link(@request_open.course.name)
      end
    end

    within(find('div.item', text: 'Remove This Item')) do
      find('.btn-group button', text: 'Update Item').click
      find('.dropdown-menu a', text: 'Remove item').click
    end
    
    accept_alert

    assert_no_text 'Remove This Item'
  end

  test 'Set reserve as removed' do
    login_as(@user)
    visit root_url

    @item1 = FactoryGirl.create(:item, request: @request_completed, title: "Item 1")
    @item2 = FactoryGirl.create(:item, request: @request_completed, title: "Item 2")

    within('tbody') do
      within(:xpath, "//tr[td[contains(text(), 'COMPLETED')]]/following-sibling::tr[1]") do
        click_link(@request_completed.course.name)
      end
    end

    first('a', text: 'Remove Item(s) From Reserve').click

    accept_alert

    assert_text 'REMOVED'
  end

  test 'Rollover dates in request' do
    login_as(@user)
    visit root_url

    @item1 = FactoryGirl.create(:item, request: @request_completed, title: "Item 1")
    @item2 = FactoryGirl.create(:item, request: @request_completed, title: "Item 2")

    within('tbody') do
      within(:xpath, "//tr[td[contains(text(), 'COMPLETED')]]/following-sibling::tr[1]") do
        click_link(@request_completed.course.name)
      end
    end

    first('a', text: 'Keep Item(s) On Reserve').click

    select('F', from: 'rollover_course_term')
    select('A', from: 'rollover_course_section')
    select('1', from: 'rollover_course_credits')
    fill_in 'rollover_course_student_count', with: 'Enrollement'

    click_button 'Keep Item(s) On Reserve'

    accept_alert

    assert_text "Your item(s) will be kept on reserve."
  end

  test 'Reopen request' do
    login_as(@user)
    visit root_url

    @item1 = FactoryGirl.create(:item, request: @request_completed, title: "Item 1")
    @item2 = FactoryGirl.create(:item, request: @request_completed, title: "Item 2")

    within('tbody') do
      within(:xpath, "//tr[td[contains(text(), 'COMPLETED')]]/following-sibling::tr[1]") do
        click_link(@request_completed.course.name)
      end
    end

    first('a', text: 'Add More Items / Re Open').click

    accept_alert

    assert_text "Status changed to open and request has been unassigned"
  end

  test 'View Request History Log' do
    login_as(@user)
    visit root_url

    within('table.request tbody') do
      first('a.name').click
    end

    click_link 'View Log'

    assert_selector('.modal', visible: true, wait: 5)

    assert_selector 'h4', text: 'Request History'
  end

  test 'View Item History Log' do
    login_as(@admin_user)
    visit root_url

    within "table.table tbody" do
      # Find the first row
      first("tr").find("td.course a.name").click
    end

    within first(".items .item") do
      click_link("Add a Note / History Log")
    end

    assert_selector('.modal', visible: true, wait: 5)

    assert_selector 'h4', text: 'Item History'
  end

  test 'Write a item note' do
    login_as(@admin_user)
    visit root_url

    click_link @request_open.course.name

    find("a[data-bs-target='#item_history_popup_#{@item_open.id}']").click

    assert_selector('.modal', visible: true, wait: 5)

    assert_selector 'h4', text: 'Item History'

    fill_in "note-textarea_#{@item_open.id}", with: 'Test Item Note'
    click_button 'Add Note'
    
    assert_selector 'p', text: 'Test Item Note'
  end

  test 'Write a request note' do
    login_as(@admin_user)
    visit root_url

    click_link @request_open.course.name

    first("a[data-target='#history_popup']").click

    assert_selector('.modal', visible: true, wait: 5)

    assert_selector 'h4', text: 'Request History'

    fill_in "note-textarea_", with: 'Test Request Note'
    click_button 'Add Note'
    
    assert_selector 'p', text: 'Test Request Note'
  end

  test 'Make request item ready' do
    login_as(@admin_user)
    visit root_url

    click_link @request_open.course.name

    within(:xpath, "//div[contains(@id, 'item_#{@item_open.id}') and .//h3[contains(text(), '#{@item_open.title}')]]") do
      find('a.change-item-status.item_not_ready').click
    end

    assert_selector('.modal', visible: true, wait: 5)

    fill_in 'item_ils_barcode', with: "1234567879"

    click_button 'Save Barcode'

    within(:xpath, "//div[contains(@id, 'item_#{@item_open.id}')]") do
      assert_equal find('span.item-status').text, 'Ready'
    end
  
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
