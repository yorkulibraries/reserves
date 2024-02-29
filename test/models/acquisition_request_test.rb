# frozen_string_literal: true

require 'test_helper'

class AcquisitionRequestTest < ActiveSupport::TestCase
  should 'create a valid acquisition request' do
    i = build(:acquisition_request)

    assert_difference 'AcquisitionRequest.count', 1 do
      i.save
    end
  end

  should 'not create an invalid acquisition_request' do
    ## blank item
    assert !build(:acquisition_request, item: nil).valid?
    assert !build(:acquisition_request, requested_by: nil).valid?
    assert !build(:acquisition_request, location: nil).valid?
  end

  should "require additional acquired fields if Status is #{AcquisitionRequest::STATUS_ACQUIRED}" do
    status = AcquisitionRequest::STATUS_ACQUIRED
    assert !build(:acquisition_request, status: status, acquired_by: nil).valid?
    assert !build(:acquisition_request, status: status, acquired_at: nil).valid?
    assert !build(:acquisition_request, status: status, acquisition_source_type: nil).valid?
    assert !build(:acquisition_request, status: status, acquisition_source_name: nil).valid?

    ## save item with field filled in
    i = create(:acquisition_request)
    i.status = AcquisitionRequest::STATUS_ACQUIRED
    i.acquired_by = create(:user)
    i.acquired_at = Time.now
    i.acquisition_source_type = 'Publisher'
    i.acquisition_source_name = 'MacMillan'

    assert i.save, 'Should save without issues on acquisition'
  end

  should "require additional cancelled fields if Status i #{AcquisitionRequest::STATUS_CANCELLED}" do
    status = AcquisitionRequest::STATUS_CANCELLED
    assert !build(:acquisition_request, status: status, cancelled_by: nil).valid?
    assert !build(:acquisition_request, status: status, cancelled_at: nil).valid?
    assert !build(:acquisition_request, status: status, cancellation_reason: nil).valid?

    ## save item with field filled in
    i = create(:acquisition_request)
    i.status = AcquisitionRequest::STATUS_CANCELLED
    i.cancelled_by = create(:user)
    i.cancelled_at = Time.now
    i.cancellation_reason = "Something didn't work, mistake"

    assert i.save, 'Should save without issues on cancellation'
  end

  should 'retrieve acquisition requests by status (scoped)' do
    create(:acquisition_request)
    create_list(:acquisition_request, 2, status: AcquisitionRequest::STATUS_ACQUIRED, acquired_at: Time.now)
    create_list(:acquisition_request, 3, status: AcquisitionRequest::STATUS_CANCELLED, cancelled_at: Time.now)

    assert_equal 3, AcquisitionRequest.cancelled.count
    assert_equal 1, AcquisitionRequest.open.count
    assert_equal 2, AcquisitionRequest.acquired.count
  end

  should 'retrieve acquisition requests by source_type' do
    create(:acquisition_request, acquisition_source_type: 'Publisher')
    create_list(:acquisition_request, 2, acquisition_source_type: 'Student')

    assert_equal 1, AcquisitionRequest.by_source_type('Publisher').count
    assert_equal 2, AcquisitionRequest.by_source_type('Student').count
  end

  should "send an email to a bookstore, acquisitoins department and location's acquisition email" do
    Setting.email_allow = true
    user = create(:user)
    location = create(:location, acquisitions_email: 'something@test.com')
    arequest = create(:acquisition_request, location: location)

    ActionMailer::Base.deliveries = []

    perform_enqueued_jobs do
      arequest.email_to(AcquisitionRequest::EMAIL_TO_BOOKSTORE, user)

      assert_equal [Setting.email_acquisitions_to_bookstore], ActionMailer::Base.deliveries.last.to
    end

    ActionMailer::Base.deliveries = []

    perform_enqueued_jobs do
      assert ActionMailer::Base.deliveries.empty?
      arequest.email_to(AcquisitionRequest::EMAIL_TO_ACQUISITIONS, user)
      assert !ActionMailer::Base.deliveries.empty?
      assert_equal [Setting.email_acquisitions_to], ActionMailer::Base.deliveries.first.to
    end

    ActionMailer::Base.deliveries = []

    perform_enqueued_jobs do
      assert ActionMailer::Base.deliveries.empty?
      arequest.email_to(nil, user)

      assert !ActionMailer::Base.deliveries.empty?
      assert_equal [arequest.location.acquisitions_email], ActionMailer::Base.deliveries.first.to
    end
  end
end
