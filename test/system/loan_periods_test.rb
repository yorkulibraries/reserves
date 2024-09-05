#frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class LoanPeriodsTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)

    @loan_period = FactoryGirl.create(:loan_period)

    @request = FactoryGirl.create(:request, status: Request::INCOMPLETE)
  end

  test 'Add a new loan period' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Loan Periods"
    click_link "Add a new loan period"

    fill_in 'loan_period_duration', with: '3 weeks'
    click_button 'Create Loan period'

    assert_selector '.alert-success', text: "Loan period was successfully created."

    assert_selector 'table.table-bordered td', text: '3 weeks'

    click_link 'Dashboard'
    click_link 'Incomplete'
    find('button .fa-home').click
    click_link "All Locations"

    click_link @request.course.name

    click_link "Book"
    assert_selector 'select#item_loan_period option', text: '3 weeks'
  end

  test 'Edit a loan period' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Loan Periods"
    find('tr', text: @loan_period.duration).click_link('Make Changes')

    fill_in 'loan_period_duration', with: '4 weeks'
    click_button 'Update Loan period'

    assert_selector '.alert-success', text: "Loan period was successfully updated."

    assert_selector 'table.table-bordered td', text: '4 weeks'
  end

  test 'Delete a loan period' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Loan Periods"
    find('tr', text: @loan_period.duration).click_link('Make Changes')

    click_link 'Remove this loan period?'

    page.accept_alert

    assert_no_text @loan_period.duration
  end

end
