# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  should 'create a valid User' do
    user = build(:user)

    assert_difference 'User.count', 1 do
      user.save
    end
  end

  should 'not create an invalid user' do
    # common validations
    assert !build(:user, email: nil).valid?, 'Should have email'
    assert !build(:user, email: 'whwoow').valid?, 'Email should follow proper format'
    assert !build(:user, uid: nil).valid?, 'Should have uid'
    assert !build(:user, name: nil).valid?, 'Should have a name'
    assert !build(:user, user_type: nil).valid?, 'Should have user type'
    assert !build(:user, role: nil).valid?, 'Staff must have a role set'
    assert !build(:user, username: nil).valid?, 'Should have a username'

    # uniqueness
    create(:user, uid: 'woot')
    assert !build(:user, uid: 'woot').valid?, 'UID must be unique'
    create(:user, username: 'woot2')
    assert !build(:user, username: 'woot2').valid?, 'username must be unique'
    create(:user, email: 'woot@woot.com')
    assert !build(:user, email: 'woot@woot.com').valid?, 'email must be unique'
  end

  should 'have staff and users scopes' do
    create_list(:user, 2, admin: true, role: User::MANAGER_ROLE)
    create_list(:user, 3, admin: false)

    assert_equal 2, User.admin.size, 'Should be 2 staff'
    assert_equal 3, User.users.size, 'Should be 3 regular users'
  end

  should "should have is_reserves_staff column" do
    assert_includes User.column_names, "is_reserves_staff"
  end
end
