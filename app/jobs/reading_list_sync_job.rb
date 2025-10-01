# frozen_string_literal: true

class ReadingListSyncJob < ApplicationJob
  queue_as :default

  def perform(request_id, actor_id = nil)
    request = Request.find(request_id)
    Alma::ReadingListSync.sync!(request_id: request.id, actor_id: actor_id)
  rescue => e
    Rails.logger.error("ReadingListSyncJob error for Request##{request_id}: #{e.message}")
  end
end
