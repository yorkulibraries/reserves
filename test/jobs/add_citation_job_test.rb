# frozen_string_literal: true

require 'test_helper'

class AddCitationJobTest < ActiveJob::TestCase
  setup do
    @user = create(:user)
    @item = create(:item)
  end

  should 'call Alma::AlmaSync.sync_item with loaded records' do
    Alma::AlmaSync.expects(:sync_item).with do |item, user|
      item.id == @item.id && user.id == @user.id
    end

    AddCitationJob.new.perform(@item.id, @user.id)
  end

  should 'no-op when item is missing' do
    Alma::AlmaSync.expects(:sync_item).never

    assert_nothing_raised do
      AddCitationJob.new.perform(-1, @user.id)
    end
  end

  should 'no-op when user is missing' do
    Alma::AlmaSync.expects(:sync_item).never

    assert_nothing_raised do
      AddCitationJob.new.perform(@item.id, -1)
    end
  end

  should 'log and re-raise when Alma sync fails' do
    failure = StandardError.new('sync failed')
    Alma::AlmaSync.expects(:sync_item).raises(failure)
    Rails.logger.expects(:error).with(regexp_matches(/sync failed/))

    assert_raises(StandardError) do
      AddCitationJob.new.perform(@item.id, @user.id)
    end
  end
end

class ReadingListSyncJobTest < ActiveJob::TestCase
  setup do
    @request = create(:request, alma_course_id: 'COURSE1', alma_reading_list_id: 'LIST1')
    @actor   = create(:user)
    Rails.logger.stubs(:error)
  end

  teardown do
    Rails.logger.unstub(:error)
  end

  should 'delegate to Alma::ReadingListSync with found request id' do
    Request.expects(:find).with(@request.id).returns(@request)
    Alma::ReadingListSync.expects(:sync!).with(request_id: @request.id, actor_id: @actor.id)

    ReadingListSyncJob.perform_now(@request.id, @actor.id)
  end

  should 'log error when sync raises' do
    Request.expects(:find).with(@request.id).returns(@request)
    Alma::ReadingListSync.expects(:sync!).raises(StandardError.new('boom'))
    Rails.logger.expects(:error).with(regexp_matches(/boom/))

    assert_nothing_raised do
      ReadingListSyncJob.perform_now(@request.id, nil)
    end
  end

  should 'handle missing request gracefully' do
    Request.expects(:find).with(-1).raises(ActiveRecord::RecordNotFound.new('not found'))
    Rails.logger.expects(:error).with(regexp_matches(/not found/))

    assert_nothing_raised do
      ReadingListSyncJob.perform_now(-1, nil)
    end
  end
end
