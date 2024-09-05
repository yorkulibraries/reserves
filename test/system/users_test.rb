# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class UsersTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    @user1 = FactoryGirl.create(:user, role: User::INSTRUCTOR_ROLE)
    @user2 = FactoryGirl.create(:user, role: User::STAFF_ROLE, active: false)
    @user3 = FactoryGirl.create(:user, role: User::STAFF_ROLE, admin: true)

    @loan_period = FactoryGirl.create(:loan_period)
  end

  test 'Add a new regular user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"
    click_link "Add New Regular User"

    fill_in 'user_name', with: 'Test User'
    fill_in 'user_email', with: 'testuser@test.com'
    fill_in 'user_uid', with: 'test_user'
    fill_in 'user_office', with: 'Test Office'
    fill_in 'user_phone', with: '1231231234'
    fill_in 'user_department', with: 'Test Department'
    select "FACULTY", from: 'user_user_type'
    click_button "Save User Details"

    assert_selector '.alert-success', text: "User was successfully created."

    find('a[aria-label="Settings"]').click
    click_link "Users"

    assert_selector 'a', text: "Test User"
  end

  test 'Submit empty form for a new regular user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"
    click_link "Add New Regular User"
    click_button "Save User Details"

    assert_selector 'span.help-block.has-error', text: "can't be blank"

    assert_no_selector '.alert-success', text: "User was successfully created."

    find('a[aria-label="Settings"]').click
    click_link "Users"

    assert_no_selector 'a', text: "Test User"
  end

  test 'Submit form for a new regular user with invalid email' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"
    click_link "Add New Regular User"

    fill_in 'user_name', with: 'Test Admin User'
    fill_in 'user_email', with: 'testadminuser'
    fill_in 'user_uid', with: 'test_admin_user'
    fill_in 'user_office', with: 'Test Admin Office'
    fill_in 'user_phone', with: '1231231234'
    fill_in 'user_department', with: 'Test Admin Department'
    select "FACULTY", from: 'user_user_type'
    click_button "Save User Details"

    assert_selector 'div.form-group.user_email.has-error'
    assert_selector 'span.help-block.has-error', text: 'is invalid'

    assert_no_selector '.alert-success', text: "User was successfully created."

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    assert_no_selector 'a', text: "Test User"
  end

  test 'Edit a regular user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"
    find('tr.user', text: @user1.name).find('span.fa-pencil').click

    fill_in 'user_name', with: 'Test User'
    click_button "Save User Details"

    assert_selector '.alert-success', text: "User Test User was successfully updated."

    find('a[aria-label="Settings"]').click
    click_link "Users"

    assert_selector 'a', text: "Test User"
  end

  test 'Block a regular user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"

    find('tr.user', text: @user1.name).find('span.fa-ban').click
    page.accept_alert

    assert_selector '.alert-success', text: "Successfully deactivated this user."

    click_link "Inactive Users"
    assert_text @user1.name
  end

  test 'Reactivate a regular user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"

    click_link "Inactive Users"
    assert_text @user2.name

    click_link "Reactivate"
    page.accept_alert

    assert_selector '.alert-success', text: "Successfully reactivate this user"

    assert_text @user2.name
  end

  test 'Promote regular user to admin user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"

    find('tr.user', text: @user1.name).find('span.fa-arrow-up').click
    page.accept_alert

    assert_selector '.alert-success', text: "Successfully made this user an admin"

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    assert_text @user1.name
  end

  test 'Add a new admin user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Admin"
    click_link "Add New Admin User"

    fill_in 'user_name', with: 'Test Admin User'
    fill_in 'user_email', with: 'testadminuser@test.com'
    fill_in 'user_uid', with: 'test_admin_user'
    fill_in 'user_office', with: 'Test Admin Office'
    fill_in 'user_phone', with: '1231231234'
    fill_in 'user_department', with: 'Test Admin Department'
    find('#user_location_id').find("option[value='1']").select_option
    select "FACULTY", from: 'user_user_type'
    select "staff", from: 'user_role'
    click_button "Save User Details"

    assert_selector '.alert-success', text: "User was successfully created."

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    assert_selector 'a', text: "Test Admin User"
  end

  test 'Submit form for a new admin user with invalid email' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Admin"
    click_link "Add New Admin User"

    fill_in 'user_name', with: 'Test Admin User'
    fill_in 'user_email', with: 'testadminuser'
    fill_in 'user_uid', with: 'test_admin_user'
    fill_in 'user_office', with: 'Test Admin Office'
    fill_in 'user_phone', with: '1231231234'
    fill_in 'user_department', with: 'Test Admin Department'
    find('#user_location_id').find("option[value='1']").select_option
    select "FACULTY", from: 'user_user_type'
    select "staff", from: 'user_role'
    click_button "Save User Details"


    assert_selector 'div.form-group.user_email.has-error'
    assert_selector 'span.help-block.has-error', text: 'is invalid'

    assert_no_selector '.alert-success', text: "User was successfully created."

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    assert_no_selector 'a', text: "Test User"
  end

  test 'Submit empty form for a new admin user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Admin"
    click_link "Add New Admin User"
    click_button "Save User Details"

    assert_selector 'span.help-block.has-error', text: "can't be blank"

    assert_no_selector '.alert-success', text: "User was successfully created."

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    assert_no_selector 'a', text: "Test User"
  end

  test 'Edit a admin user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    find('tr.user', text: @user3.name).find('a', text: 'Update details').click

    fill_in 'user_name', with: 'Test Admin User'
    click_button "Save User Details"

    assert_selector '.alert-success', text: "User Test Admin User was successfully updated."

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    assert_selector 'a', text: "Test Admin User"
  end

  test 'Block a admin user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    find('tr.user', text: @user3.name).find('a', text: 'Block user access').click
    page.accept_alert

    assert_selector '.alert-success', text: "Successfully deactivated this user."

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    assert_no_selector 'a', text: @user3.name
  end

  test 'Change admin user to regular user' do
    login_as(@user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Admin"

    find('tr.user', text: @user3.name).find('a', text: 'Change to regular user').click
    page.accept_alert

    assert_selector '.alert-success', text: "Successfully made this user a regular user"

    assert_selector 'a', text: @user3.name
  end

end
