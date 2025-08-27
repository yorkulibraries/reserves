# frozen_string_literal: true

require 'test_helper'

class RequestWizardControllerTest < ActionDispatch::IntegrationTest
  def stub_course_from_info!(course = create(:course))
    RequestWizardController.any_instance
      .stubs(:ensure_course_from_info!)
      .returns(course)
    course
  end

  setup do
    @location = create(:location)
    @course   = create(:course)

    @user  = create(:user, admin: true, role: User::MANAGER_ROLE)
    @user2 = create(:user, admin: true, role: User::MANAGER_ROLE)
    log_user_in(@user)
  end

  should 'show new request form - STEP ONE' do
    get new_request_step_one_path
    assert_response :success
    assert get_instance_var(:request)
  end

  should 'create the request from step one and move onto step two (set status to INCOMPLETE)' do
    stub_course_from_info!
    assert_difference('Request.count') do
      request_attributes = attributes_for(:request, reserve_location_id: @location.id)
      request_attributes[:course_info_id] = 123
      request_attributes[:user] = { office: '1234 building', department: 'Department of sorts', phone: '1232312312321' }

      post new_request_step_one_save_path, params: { request: request_attributes }

      request = get_instance_var(:request)
      assert_equal 0, request.errors.size, "Should be no errors, #{request.errors.messages.inspect}"
      assert_equal Request::INCOMPLETE, request.status, 'Status should be set to INCOMPLETE'
      assert_redirected_to new_request_step_two_path(request), 'Should redirect to Step Two'
      assert_equal @user.id, request.requester.id, 'Requester id was set'
    end
  end

  should 'create a new course with the same user and reuse it without showing an error' do
    stub_course_from_info!

    request_attributes = attributes_for(:request, reserve_location_id: @location.id)
    request_attributes[:course_info_id] = 123
    request_attributes[:user] = { office: '1234 building', department: 'Department of sorts', phone: '1232312312321' }

    post new_request_step_one_save_path, params: { request: request_attributes }
    existing = get_instance_var(:request)
    assert existing.present?

    post new_request_step_one_save_path, params: { request: request_attributes }

    assert_redirected_to new_request_step_two_path(existing), 'Should redirect to Step Two of existing request'
    assert_equal 'Proceeding to Step 2.', flash[:notice]
  end

  should 'not create a new course with a different user and still reuse the existing request' do
    stub_course_from_info!

    request_attributes = attributes_for(:request, reserve_location_id: @location.id)
    request_attributes[:course_info_id] = 123
    request_attributes[:user] = { office: '1234 building', department: 'Department of sorts', phone: '1232312312321' }

    post new_request_step_one_save_path, params: { request: request_attributes }
    existing = get_instance_var(:request)
    assert existing.present?

    logout
    log_user_in(@user2)

    post new_request_step_one_save_path, params: { request: request_attributes }

    assert_redirected_to new_request_step_two_path(existing)
    assert_equal 'Proceeding to Step 2.', flash[:notice]
  end

  should 'handle empty new request' do
    assert_no_difference('Request.count') do
      request_attributes = attributes_for(:request, reserve_location_id: @location.id)
      request_attributes[:course_info_id] = nil
      request_attributes[:user] = { office: '', department: '', phone: '' }

      post new_request_step_one_save_path, params: { request: request_attributes }

      assert_response :success
      assert_match /Course cannot be empty/, @response.body
    end
  end

  should 'load the request and any items, if coming back to this' do
    request = create(:request, status: Request::INCOMPLETE)

    get new_request_step_two_path(request)
    assert_response :success

    assert get_instance_var(:items)
    assert get_instance_var(:request)
  end

  test 'should finalize request (change status to OPEN) if there is at least one item attached' do
    request = create(:request, status: Request::INCOMPLETE)

    post new_request_finish_path(request)
    r = get_instance_var(:request)
    assert_equal Request::INCOMPLETE, r.status, 'Status should still be incomplete'
    assert_response :redirect
    assert_redirected_to new_request_step_two_path(request),
                         'Should redirect to Step Two since there are no items attached'

    create(:item, request: request)

    assert_enqueued_emails 1 do
      post new_request_finish_path(request)
    end
    r = get_instance_var(:request)
    assert_equal Request::OPEN, r.status, 'Status should now be OPEN'

    assert_response :redirect
    assert_redirected_to request_path(request), 'Show request details'
  end

  test 'should not allow finishing the request without items' do
    request = create(:request, status: Request::INCOMPLETE)

    get new_request_step_two_path(request)
    assert_response :success
    assert_match /Save this request for later/, @response.body
    assert_no_match /I am done, submit this request/, @response.body

    post new_request_finish_path(request)
    assert_redirected_to new_request_step_two_path(request)
    follow_redirect!
    assert_match /You must add at least one active item for this request to be submitted!/, @response.body
  end

  should 'not allow saving if course_id is invalid' do
    RequestWizardController.any_instance
      .stubs(:ensure_course_from_info!)
      .returns(nil)

    request_attributes = attributes_for(:request, reserve_location_id: @location.id)
    request_attributes[:course_info_id] = 9999 # non-blank but invalid
    request_attributes[:user] = { office: '', department: '', phone: '' }

    assert_no_difference('Request.count') do
      post new_request_step_one_save_path, params: { request: request_attributes }
    end

    assert_response :success
    assert_match /Course not found/, @response.body
  end

  should 'redirect to existing request if one already exists for course_id' do
    course = create(:course)
    existing_request = create(:request, course: course)

    stub_course_from_info!(course)

    request_attributes = attributes_for(:request, reserve_location_id: @location.id)
    request_attributes[:course_info_id] = 123
    request_attributes[:user] = { office: '', department: '', phone: '' }

    post new_request_step_one_save_path, params: { request: request_attributes }

    assert_redirected_to new_request_step_two_path(existing_request)
    assert_equal 'Proceeding to Step 2.', flash[:notice]
  end

  should 'call Alma::AlmaSync.sync_request on successful save' do
    stub_course_from_info!

    request_attributes = attributes_for(:request, reserve_location_id: @location.id)
    request_attributes[:course_info_id] = 123
    request_attributes[:user] = { office: '', department: '', phone: '' }

    Alma::AlmaSync.expects(:sync_request).once

    post new_request_step_one_save_path, params: { request: request_attributes }

    request = get_instance_var(:request)
    assert_redirected_to new_request_step_two_path(request)
  end

  should 'update current user contact details during save' do
    stub_course_from_info!

    user_attrs = { office: 'New Tower', department: 'New Dept', phone: '9876543210' }

    request_attributes = attributes_for(:request, reserve_location_id: @location.id)
    request_attributes[:course_info_id] = 123
    request_attributes[:user] = user_attrs

    post new_request_step_one_save_path, params: { request: request_attributes }

    @user.reload
    assert_equal 'New Tower', @user.office
    assert_equal 'New Dept', @user.department
    assert_equal '9876543210', @user.phone
  end

  should 'handle Alma::AlmaSync.sync_request failure gracefully' do
    stub_course_from_info!

    request_attributes = attributes_for(:request, reserve_location_id: @location.id)
    request_attributes[:course_info_id] = 123
    request_attributes[:user] = { office: '', department: '', phone: '' }

    Alma::AlmaSync.expects(:sync_request).raises(StandardError.new("💥 API went boom"))

    assert_nothing_raised do
      post new_request_step_one_save_path, params: { request: request_attributes }
    end

    request = get_instance_var(:request)
    assert_redirected_to new_request_step_two_path(request)
  end
end
