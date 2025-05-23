# frozen_string_literal: true

require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest

  should 'not throw authorization not performed error when using the controller' do
    assert_nothing_raised do
      get login_url
    end
  end

  should 'create a new session information if user logs in' do
    user = create(:user, uid: 'test', admin: true, role: User::MANAGER_ROLE)

    log_user_in(user)

    assert_equal user.id, session[:user_id]
    assert_redirected_to root_url
    assert_equal 'Logged in!', flash[:notice]
  end

  should 'test redirection to a dashboard if the staff is logged in' do
    staff = create(:user, uid: '123123123', admin: true, role: User::STAFF_ROLE)
    log_user_in(staff)

    assert_equal staff.id, session[:user_id]
    assert_redirected_to root_url
  end

  should 'test redirection to a requests_user_url if the regulard user is logged in' do
    user = create(:user, uid: '123123123', admin: false)
    log_user_in(user)

    assert_equal user.id, session[:user_id]
    assert_redirected_to requests_user_url(user)
  end

  should 'show error 401 if user is not active' do
    user = create(:user, uid: '123123123', admin: false, active: false)
    log_user_in(user)
    assert_equal 401, response.status
    assert_not_nil flash[:alert]
    assert_equal 'User not active.', flash[:alert]
  end

  should "NEW USER, redirect to new user signup if user doesn't exist, no email should be sent yet" do
    ActionMailer::Base.deliveries.clear
    get logout_url
    get login_url, headers: { 
      'HTTP_PYORK_USER' => 'something_or_other', 'HTTP_PYORK_EMAIL' => 'something@email.com', 
      'HTTP_PYORK_CYIN' => '999999999', 'HTTP_PYORK_TYPE' => User::FACULTY,
      'HTTP_PYORK_SURNAME' => 'doe', 'HTTP_PYORK_FIRSTNAME' => 'john'
    }
    assert ActionMailer::Base.deliveries.empty?, "Should be empty, since we didn't get any details about user"
    assert_not_nil session[:user_id], 'Make sure user is logged in'

    assert_redirected_to edit_user_url(session[:user_id]), 'Should redirect to edit user page, for brand new user'
  end

  should 'destroy session information when logout is present' do
    get logout_url

    assert_nil session[:user_id]
    assert_redirected_to Warden::PpyAuthStrategy::PPY_LOGOUT_URL
  end

  context 'logged in actions' do
    setup do
      @user = create(:user, admin: true, role: User::MANAGER_ROLE)
      log_user_in(@user)
    end

    should 'be able to login as requestor' do
      requestor = create(:user)

      assert_difference('Audited::Audit.count') do
        get login_as_url, params: { who: requestor.id }
        assert_redirected_to requests_user_url(requestor), 'Should be redirected to user'
        assert_equal requestor.id, session[:user_id], 'New user '
        assert_equal @user.id, session[:back_to_id], 'Record where to return back to'
      end
    end

    should 'not be able to login as staff user' do
      staff_user = create(:user, admin: true, role: User::MANAGER_ROLE)

      get login_as_url, params: { who: staff_user.id }
      assert_redirected_to root_url, 'should redirect to root url'
      assert_equal @user.id, session[:user_id], 'same user still logged in'
      assert_nil session[:back_to_id], 'Back to id should be nil'
    end

    should 'go back to my login' do
      requestor = create(:user)

      # session[:back_to_id] = @user.id
      # session[:user_id] = requestor.id

      # Simulate logging in as another user
      assert_difference('Audited::Audit.count', 1, 'login_as should create an audit entry') do
        get login_as_url, params: { who: requestor.id }
        assert_equal requestor.id, session[:user_id], 'Should be impersonating requestor'
      end

      # Now go back to original login
      assert_difference('Audited::Audit.count', 1, 'back_to_my_login should create an audit entry') do
        get back_to_my_login_url
      end

      assert_equal @user.id, session[:user_id], 'Should return to original user session'
      assert_nil session[:back_to_id], 'Back to ID should be cleared'
    end
  end
end
