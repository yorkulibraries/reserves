# frozen_string_literal: true

class AlmaStatusSweepJob < ApplicationJob
  queue_as :default

  def perform
    Request.where.not(alma_course_id: nil, alma_reading_list_id: nil)
           .find_each(batch_size: 100) do |request|
      ReadingListSyncJob.perform_now(request.id)
    rescue => e
      Rails.logger.error(
        "AlmaStatusSweepJob: unable to enqueue sync for Request##{request.id}: #{e.class}: #{e.message}"
      )
    end
  end
end
