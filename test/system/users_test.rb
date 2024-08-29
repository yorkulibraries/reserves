# frozen_string_literal: true

require 'application_system_test_case'
require 'helpers/system_test_helper'

class UsersTest < ApplicationSystemTestCase
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @user1 = FactoryGirl.create(:user, role: User::INSTRUCTOR_ROLE)
    @user2 = FactoryGirl.create(:user, role: User::SUPERVISOR_ROLE)
    @user3 = FactoryGirl.create(:user, role: User::STAFF_ROLE)
  end

  test 'Add a new regular user' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)
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

  test 'Block a regular user' do
    user = FactoryGirl.create(:user, role: User::MANAGER_ROLE, admin: true)
    login_as(user)
    visit root_url

    find('a[aria-label="Settings"]').click
    click_link "Users"

    within(:xpath, "//tr[.//a/strong[text()=#{@user1.name}]]") do
      find('a[data-confirm="Are you sure? "] .fa.fa-ban').click
    end
    page.accept_alert

    assert_selector '.alert-success', text: "Successfully deactivated this user."

    click_link "Inactive Users"
    assert_text @user1.name
  end

end
