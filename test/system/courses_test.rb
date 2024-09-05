#frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class CoursesTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)

    @course1 = FactoryGirl.create(:course)
    @course2 = FactoryGirl.create(:course)

    @request = FactoryGirl.create(:request, course: @course1, status: Request::INCOMPLETE)
  end

  test 'Edit a course' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Courses"
    find('tr', text: @course1.name).click_link('Make Changes')

    fill_in 'course_name', with: 'Course Title Test'
    fill_in 'course_instructor', with: 'Instructor Test'
    click_button 'Update Course'

    assert_selector '.alert-success', text: "Course was successfully updated."

    assert_selector 'table.table-bordered td', text: 'Course Title Test'
    assert_selector 'table.table-bordered td', text: 'Instructor Test'

    click_link "Active Courses"

    assert_selector 'a', text: "Course Title Test"
    assert_selector '.row.course-details li span.smaller', text: 'Instructor Test'

    click_link 'Dashboard'
    click_link 'Incomplete'
    find('button .fa-home').click
    click_link "All Locations"

    assert_selector 'a', text: 'Course Title Test'
  end

  test 'Search a course' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Search"]').click
    fill_in 'q', with: @request.course.name
    find('input[name="q"]').send_keys(:enter)

    assert_selector 'a', text: @request.course.name
  end

end
