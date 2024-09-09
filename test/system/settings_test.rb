#frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class SettingsTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    @course_subject = FactoryGirl.create(:courses_subject)
    @course_faculty = FactoryGirl.create(:courses_faculty)
  end

  test 'Change app name' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "General"

    fill_in 'setting_app_name', with: 'App Name Test'
    click_button 'Save Settings'

    assert_selector 'a.navbar-brand span', text: 'App Name Test'
  end

  test 'Change app owner' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "General"

    fill_in 'setting_app_owner', with: 'App Owner Test'
    click_button 'Save Settings'

    assert_selector 'a.navbar-brand span', text: 'App Owner Test'
  end

  test 'Change Default Report Interval' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "General"

    select "90 days", from: 'setting_reports_default_interval'
    click_button 'Save Settings'

    find('a[aria-label="Settings"]').click
    click_link "Reports"

    assert_selector 'a', text: 'Expiring Requests in 3 months'
    assert_selector 'a', text: 'Items Created in the last 3 months'
    assert_selector 'p', text: 'Items By Type, Last 3 months'
  end

  test 'Change Fiscal Year Start' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "General"

    fill_in 'setting_reports_fiscal_year_start', with: 'Jan 1'
    click_button 'Save Settings'

    find('a[aria-label="Settings"]').click
    click_link "Reports"

    assert_selector 'ul.list-group li.list-group-item h4', text: "Fiscal - (Jan 1, #{Course::ACADEMIC_YEARS_FULL.first[1]} to Today)"
  end

  test 'Change App Maintenance' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "General"

    fill_in 'setting_app_maintenance_message', with: 'App Maintenance Test'
    choose 'setting_app_maintenance_true'
    click_button 'Save Settings'

    assert_selector '.alert-danger', text: "App Maintenance Test"
  end

  test 'Change Help Settings' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Help"

    fill_in 'setting_help_title', with: 'Help Title Test'
    fill_in 'setting_help_link', with: 'www.test.com'
    fill_in 'setting_help_body', with: 'Help Body Test'
    fill_in 'setting_help_contact', with: 'Help Contact Test'
    click_button 'Save Help Settings'

    assert_selector '.alert-success', text: "Saved Help Settings"

    find('a[aria-label="Help"]').click

    assert_selector 'h4', text: "Help Title Test"
    assert_selector 'p', text: "Help Body Test"
    assert_selector 'p', text: "Help Contact Test"
    assert_selector 'a[href="www.test.com"]'
  end


  test 'Add new course subject' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Course Subjects"
    click_link "New Course Subject"

    fill_in 'courses_subject_code', with: '1234'
    fill_in 'courses_subject_name', with: 'Name Test'
    click_button 'Create Subject'

    assert_selector '.alert-success', text: "1234 subject was created!"

    assert_selector 'td', text: '1234'
    assert_selector 'td', text: 'Name Test'

    click_link "New Request"
    assert_selector 'select#request_course_attributes_subject option', text: '1234'

  end

  test 'Edit course subject' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Course Subjects"
    assert_selector("tr", text: "COD") { click_link("Make Changes") }

    fill_in 'courses_subject_code', with: '1234'
    fill_in 'courses_subject_name', with: 'Name Test'
    click_button 'Update Subject'

    assert_selector '.alert-success', text: "1234 subject was updated!"

    assert_selector 'td', text: '1234'
    assert_selector 'td', text: 'Name Test'

    click_link "New Request"
    assert_selector 'select#request_course_attributes_subject option', text: '1234'
  end

  test 'Delete a course subject' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Course Subjects"
    assert_selector("tr", text: "COD") { click_link("Make Changes") }

    click_link 'Remove Course Subject'

    page.accept_alert

    assert_selector '.alert-success', text: "COD subject was removed!"
  end

  test 'Add new course faculty' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Course Faculties"
    click_link "New Course Faculty"

    fill_in 'courses_faculty_code', with: '1234'
    fill_in 'courses_faculty_name', with: 'Name Test'
    click_button 'Create Faculty'

    assert_selector '.alert-success', text: "1234 faculty was created!"

    assert_selector 'td', text: '1234'
    assert_selector 'td', text: 'Name Test'

    click_link "New Request"
    assert_selector 'select#request_course_attributes_faculty option', text: '1234'

  end

  test 'Edit course faculty' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Course Faculties"
    assert_selector("tr", text: "MyString") { click_link("Make Changes") }

    fill_in 'courses_faculty_code', with: '3213'
    fill_in 'courses_faculty_name', with: 'Name Test'
    click_button 'Update Faculty'

    assert_selector '.alert-success', text: "3213 faculty was updated!"

    assert_selector 'td', text: '3213'
    assert_selector 'td', text: 'Name Test'

    click_link "New Request"
    assert_selector 'select#request_course_attributes_faculty option', text: '3213'
  end

  test 'Delete a course faculties' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Course Faculties"
    assert_selector("tr", text: "MyString") { click_link("Make Changes") }
    
    click_link 'Remove Course Faculty'

    page.accept_alert

    assert_selector '.alert-success', text: "MyString faculty was removed!"
  end

end
