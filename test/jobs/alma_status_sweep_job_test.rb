# frozen_string_literal: true

require 'test_helper'

class AlmaStatusSweepJobTest < ActiveJob::TestCase
  test 'enqueues reading list sync jobs for requests with Alma identifiers' do
    request = create(:request, alma_course_id: 'COURSE1', alma_reading_list_id: 'LIST1')

    ReadingListSyncJob.expects(:perform_now).with(request.id).once

    AlmaStatusSweepJob.perform_now
  end

  test 'ignores requests missing Alma identifiers' do
    create(:request, alma_course_id: nil, alma_reading_list_id: nil)

    ReadingListSyncJob.expects(:perform_now).never

    AlmaStatusSweepJob.perform_now
  end
end
