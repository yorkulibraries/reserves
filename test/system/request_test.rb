# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'
require 'devise/test/integration_helpers' # Add this line
require 'securerandom'

class RequestTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers # Include the Devise helpers
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @admin_user = create(:user, admin: true, role: User::MANAGER_ROLE)
    @user = FactoryGirl.create(:user, role: User::INSTRUCTOR_ROLE)
    @loan_period = FactoryGirl.create(:loan_period, duration: '2 Hours')
    @location = create(:location, name: 'Steacie Library')

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

  # COME BACK - CAN'T TRIGGER REQUEST COURSE INPUT IN TEST
  # test 'search for non-existing course' do
  #   login_as(@user)
  #   visit root_url

  #   click_link('New Request')

  #   # Search for a non-existing course
  #   fill_in 'request_course_id', with: 'Non-existing Course'

  #   # Submit the form
  #   click_button 'Continue to Step Two'

  #   # Ensure that an appropriate error message is displayed for no results
  #   assert_text 'No course found matching your search'
  # end

  test 'Submit empty request' do
    login_as(@user)
    visit root_url

    click_link('New Request')

    assert_text "Submit New Request - Step One"

    click_button 'Continue to Step Two'

    assert_text "Submit New Request - Step One"
    assert_text "Course cannot be empty"
  end

  test 'Add manual citation item from request wizard' do
    request = build_incomplete_request

    login_as(@user)
    visit new_request_step_two_path(request)

    assert_text 'Submit New Request - Step Two'

    find('button', text: 'Book').click
    within(find('.dropdown-menu', visible: true)) { click_link 'Enter citation' }

    assert_selector '#item_form', visible: true

    within '#item_form' do
      fill_in 'item_title', with: 'Economics of Growth'
      fill_in 'item_author', with: 'John Smith'
      fill_in 'item_publisher', with: 'Academic Press'
      fill_in 'item_isbn', with: '9781234567897'
      fill_in 'item_other_isbn_issn', with: '9781234567890'
      fill_in 'item_publication_date', with: '2024'
      select @loan_period.duration, from: 'item_loan_period'
      choose 'No'

      click_button 'Create Item'
    end

    assert_no_selector '#item_form', visible: true, wait: 10
    assert_selector '.items .item', text: 'Economics of Growth'

    assert_selector '#submit_request_button', wait: 10
    click_link 'I am done, submit this request'

    assert_current_path request_path(request)
    request.reload
    assert_equal Request::OPEN, request.status
    assert_text 'Request #'
    assert_text 'Economics of Growth'
    assert_text 'Open'
  end

  test 'Add Primo search item from request wizard' do
    sample_record = primo_record(title: 'Primo Economics', author: 'Alex Primo')
    BibFinder.any_instance.stubs(:search_primo).returns([sample_record])

    request = build_incomplete_request

    login_as(@user)
    visit new_request_step_two_path(request)
    assert_text 'Submit New Request - Step Two'

    find('button', text: 'Book').click
    within(find('.dropdown-menu', visible: true)) { click_link 'Search in Primo' }

    assert_selector '#item_form', visible: true

    within '#item_form' do
      find('input[name="q"]').set('Economics')
      click_button 'Go!'
    end

    assert_selector '#search_primo_results', wait: 10

    within '#search_primo_results' do
      click_link 'Use This'
    end

    assert_no_selector '#search_primo_results', wait: 10
    within '#item_form' do
      assert_field 'item_title', with: 'Primo Economics'
      select @loan_period.duration, from: 'item_loan_period'
      choose 'No'
      click_button 'Create Item'
    end

    assert_no_selector '#item_form', visible: true, wait: 10
    assert_selector '.items .item', text: 'Primo Economics'

    assert_selector '#submit_request_button', wait: 10
    click_link 'I am done, submit this request'

    assert_current_path request_path(request)
    request.reload
    assert_equal Request::OPEN, request.status
    assert_text 'Primo Economics'
  end

  test 'Add Alma linked item from request wizard' do
    AlmaService.expects(:fetch_bib).with('991234567890123456').returns(
      {
        'title' => 'Linked Macroeconomics /',
        'title_clean' => 'Linked Macroeconomics',
        'author' => 'Jamie Alma',
        'publication_date' => '2023',
        'publisher' => 'Alma Press',
        'edition' => '3rd ed.',
        'isbn' => '9782222222222',
        'other_isbn_issn' => '9782222222223',
        'callnumber' => 'QA999 .A45 2023',
        'description' => 'A linked Alma record.'
      }
    )

    request = build_incomplete_request

    login_as(@user)
    visit new_request_step_two_path(request)
    assert_text 'Submit New Request - Step Two'

    find('button', text: 'Book').click
    within(find('.dropdown-menu', visible: true)) { click_link 'Link Alma record' }

    assert_selector '#item_form', visible: true

    within '#item_form' do
      fill_in 'alma_mms_id', with: '991234567890123456'
      click_button 'Use MMS ID'

      assert field_value_starts_with?('item_title', 'Linked Macroeconomics'), 'Expected title to start with Linked Macroeconomics'
      assert_field 'item_author', with: 'Jamie Alma'
      select @loan_period.duration, from: 'item_loan_period'
      choose 'No'

      click_button 'Create Item'
    end

    assert_no_selector '#item_form', visible: true, wait: 10
    assert_selector '.items .item', text: 'Linked Macroeconomics'

    assert_selector '#submit_request_button', wait: 10
    click_link 'I am done, submit this request'

    assert_current_path request_path(request)
    request.reload
    assert_equal Request::OPEN, request.status
    assert_text 'Linked Macroeconomics'
  end

  test 'Manual citation flow surfaces validation errors' do
    request = build_incomplete_request

    login_as(@user)
    visit new_request_step_two_path(request)
    assert_text 'Submit New Request - Step Two'

    find('button', text: 'Book').click
    within(find('.dropdown-menu', visible: true)) { click_link 'Enter citation' }

    assert_selector '#item_form', visible: true

    within '#item_form' do
      fill_in 'item_title', with: ' '
      fill_in 'item_author', with: ' '
      fill_in 'item_publisher', with: ' '
      fill_in 'item_isbn', with: ' '
      select @loan_period.duration, from: 'item_loan_period'
      choose 'No'

      click_button 'Create Item'
    end

    assert_selector '#item_form .error_messages', text: 'Oops!'
    assert_selector '#item_form', visible: true
    assert_selector '.items-empty-slate'
  end

  test 'Primo flow surfaces validation errors when data cleared' do
    BibFinder.any_instance.stubs(:search_primo).returns([primo_record])
    request = build_incomplete_request

    login_as(@user)
    visit new_request_step_two_path(request)
    assert_text 'Submit New Request - Step Two'

    find('button', text: 'Book').click
    within(find('.dropdown-menu', visible: true)) { click_link 'Search in Primo' }

    assert_selector '#item_form', visible: true

    within '#item_form' do
      find('input[name="q"]').set('Economics')
      click_button 'Go!'
    end

    assert_selector '#search_primo_results', wait: 10
    within '#search_primo_results' do
      click_link 'Use This'
    end

    within '#item_form' do
      assert_field 'item_title', with: 'Primo Economics', wait: 10
      fill_in 'item_publisher', with: ' '
      select @loan_period.duration, from: 'item_loan_period'
      choose 'No'
      click_button 'Create Item'
    end

    assert_selector '#item_form .error_messages', text: 'Oops!'
    assert_selector '#item_form', visible: true
  end

  test 'Alma flow surfaces validation errors when required data removed' do
    AlmaService.expects(:fetch_bib).with('990000000000000').returns(
      {
        'title' => 'Test Alma Resource /',
        'title_clean' => 'Test Alma Resource',
        'author' => 'Alma Author',
        'publication_date' => '2020',
        'publisher' => 'Alma Publisher',
        'edition' => '1st ed.',
        'isbn' => '9780000000000',
        'other_isbn_issn' => '9780000000001',
        'callnumber' => 'QA000 .A45 2020'
      }
    )

    request = build_incomplete_request

    login_as(@user)
    visit new_request_step_two_path(request)
    assert_text 'Submit New Request - Step Two'

    find('button', text: 'Book').click
    within(find('.dropdown-menu', visible: true)) { click_link 'Link Alma record' }

    assert_selector '#item_form', visible: true

    within '#item_form' do
      fill_in 'alma_mms_id', with: '990000000000000'
      click_button 'Use MMS ID'

      assert_field 'item_author', with: 'Alma Author', wait: 10
      fill_in 'item_publisher', with: ' '
      select @loan_period.duration, from: 'item_loan_period'
      choose 'No'
      click_button 'Create Item'
    end

    assert_selector '#item_form .error_messages', text: 'Oops!'
    assert_selector '#item_form', visible: true
  end

  test 'Admin assigns request to reserves staff from show page' do
    other_staff = create(:user, admin: true, role: User::MANAGER_ROLE, is_reserves_staff: true, name: 'Jane Admin')

    login_as(@admin_user)
    visit request_path(@request_open)

    assert_selector('button', text: /Assigned to:/)

    find('button', text: /Assigned to:/).click
    within(find('.dropdown-menu', visible: true)) do
      click_link 'Jane Admin'
    end

    assert_text 'Assigned to Jane Admin'
    assert_selector('button', text: /Assigned to:\s*Jane Admin/)
  end

  # COME BACK - CAN'T TRIGGER REQUEST COURSE INPUT IN TEST
  # test 'Complete step one' do
  #   login_as(@user)
  #   visit root_url

  #   click_link('New Request')
  #   academic_year = "#{Time.current.year}/#{Time.current.year + 1}"
  #   fill_in 'request_course_id', with: 'ECON', wait: 5

  #   fill_in 'request_course_attributes_student_count', with: '1234'
  #   fill_in 'request_requester_email', with: 'email@test.com'
  #   first_option = find('#request_reserve_location_id').all('option')[1]
  #   select(first_option.text, from: 'request_reserve_location_id')
    
  #   click_button 'Continue to Step Two'

  #   assert_text "Submit New Request - Step Two"
  # end

  # COME BACK - CAN'T TRIGGER REQUEST COURSE INPUT IN TEST
  # test 'Complete request' do
  #   login_as(@user)
  #   visit root_url

  #   click_link('New Request')
  #   academic_year = "#{Time.current.year}/#{Time.current.year + 1}"
  #   fill_in 'request_course_id', with: 'ECON'
  #   fill_in 'request_course_attributes_student_count', with: '1234'
  #   fill_in 'request_requester_email', with: 'email@test.com'
  #   first_option = find('#request_reserve_location_id').all('option')[1]
  #   select(first_option.text, from: 'request_reserve_location_id')
    
  #   click_button 'Continue to Step Two'

  #   assert_text "Submit New Request - Step Two"

  #   click_link 'Book'

  #   assert_selector '#item_form', visible: true

  #   fill_in 'item_title', with: 'Book Title'
  #   fill_in 'item_author', with: 'Book Author'
  #   fill_in 'item_publisher', with: 'Book Publisher'
  #   fill_in 'item_isbn', with: '123456789'
  #   select('2 Hours', from: 'item_loan_period')

  #   click_button 'Create Item' 
  #   save_page

  #   sleep(1)
  #   # Ensure the modal disappears completely before proceeding
  #   assert_no_selector '#item_form', visible: true
    
  #   click_link 'I am done, submit this request'
    
  #   assert_text 'Request #'
  #   assert_text 'Open'

  #   click_link "Reserves"

  #   assert_text 'Course Title'
  # end

  # COME BACK - CAN'T TRIGGER REQUEST COURSE INPUT IN TEST
  # test 'Update request details' do
  #   # Ensure the autocomplete endpoint has data to return
  #   Course.reindex
  
  #   login_as(@user)
  #   visit root_url
  
  #   within('table.request tbody') { first('a.name').click }
  #   click_link 'Update Request'
  #   assert_text 'Make Changes To Request'
  
  #   field = find('#request_course_search', visible: true)
  #   field.click
  
  #   # Type slowly to guarantee key events & minLength(4) behavior
  #   '2025_GL_ECON'.each_char { |ch| field.send_keys(ch) }
  
  #   # Wait for any suggestion to appear (the wrapper is the clickable element)
  #   assert_selector('ul.ui-autocomplete li .ui-menu-item-wrapper', wait: 10)
  
  #   # Option A (most resilient): use keyboard to select the first suggestion
  #   field.send_keys(:arrow_down, :enter)
  
  #   # OR Option B (explicit match): click a specific suggestion text
  #   # find('ul.ui-autocomplete li .ui-menu-item-wrapper',
  #   #      text: '2025_GL_ECON_S1_2500__3_A', match: :first).click
  
  #   # Now the hidden field should be set by your select handler
  #   assert_field('request_course_attributes_course_id',
  #                with: @course.id.to_s,
  #                visible: :all)
  
  #   click_button 'Update Request Details'
  #   assert_text 'Request was successfully updated.'
  # end

  test 'visiting request syncs with Alma and shows notice' do
    unique_suffix = SecureRandom.hex(2).upcase
    unique_course = create(:course, code: "2026_GL_TEST_F_2100__3_A_#{unique_suffix}")
    request = create(
      :request,
      requester: @user,
      course: unique_course,
      alma_course_id: 'COURSE1',
      alma_reading_list_id: 'LIST1'
    )

    login_as(@admin_user)
    Alma::ReadingListSync.expects(:sync!)
                         .with(request_id: request.id, actor_id: @admin_user.id)
                         .returns({ status: :ok, added_local: 1, failed_local: 0 })

    visit request_path(request)

    assert_text 'New Items found. Synced 1 item(s) with Alma.'
  end

  # test 'Update request item' do
  #   login_as(@user)
  #   visit root_url

  #   within('table.request tbody') do
  #     first('a.name').click
  #   end

  #   first('button', text: 'Update Item').click

  #   menu = find('.btn-group .dropdown-menu', visible: true)
  #   dropdown = menu.first('.stick-on-click', minimum: 1, wait: 5)
  #   toggle = dropdown.find('.dropdown-toggle', text: 'Change Item Details')
  #   toggle.hover

  #   submenu = dropdown.find('.dropdown-menu', visible: :all, wait: 5)
  #   page.execute_script('arguments[0].classList.add("force-open"); arguments[1].style.display = "block";', dropdown.native, submenu.native)

  #   submenu.find('a', text: 'Enter citation', visible: :all, wait: 5).click

  #   assert_selector('.modal', visible: true, wait: 5)

  #   fill_in 'item_title', with: 'Test Update Item Title'

  #   fill_in 'item_author', with: 'Test Update Item Author'

  #   fill_in 'item_publisher', with: 'Test Update Item Publisher'

  #   find('input[type="submit"][value="Update Item"]').click

  #   assert_text 'Test Update Item Title'

  #   assert_text 'Test Update Item Author'

  #   assert_text 'Test Update Item Publisher'

  # end

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

  private

  def build_incomplete_request(overrides = {})
    defaults = {
      status: Request::INCOMPLETE,
      requester: @user,
      reserve_location: @location,
      assigned_to: nil,
      assigned_to_id: nil,
      requester_email: nil,
      course: create(:course)
    }

    create(:request, defaults.merge(overrides))
  end

  def primo_record(overrides = {})
    BibResult.new.tap do |record|
      record.title = overrides.fetch(:title, 'Primo Economics')
      record.author = overrides.fetch(:author, 'Alex Primo')
      record.isbn_issn = overrides.fetch(:isbn_issn, '9781111111111')
      record.other_isbn_issn = overrides.fetch(:other_isbn_issn, '9781111111112')
      record.callnumber = overrides.fetch(:callnumber, 'QA123 .P75 2022')
      record.publication_date = overrides.fetch(:publication_date, '2022')
      record.publisher = overrides.fetch(:publisher, 'Primo Press')
      record.edition = overrides.fetch(:edition, '2nd ed.')
      record.item_type = overrides.fetch(:item_type, 'book')
      record.description = overrides.fetch(:description, 'Book')
      record.main_location = overrides.fetch(:main_location, 'Scott Library')
      record.url = overrides.fetch(:url, 'https://example.com/primo')
      record.rtype = overrides.fetch(:rtype, 'books')
    end
  end

  def field_value_starts_with?(field, expected_prefix)
    value = find_field(field, wait: 10).value
    value&.start_with?(expected_prefix)
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
