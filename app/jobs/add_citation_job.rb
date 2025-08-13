class AddCitationJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: 10.seconds, attempts: 2
    def perform(item_id, user_id)
      item = Item.find_by(id: item_id)
      user = User.find_by(id: user_id)
  
      unless item && user
        Rails.logger.error("❌ AddCitationJob: Invalid item or user (item_id: #{item_id}, user_id: #{user_id})")
        return
      end
  
      Rails.logger.info("🚀 AddCitationJob: Starting citation for Item##{item_id}")
  
      Alma::AlmaSync.sync_item(item, user)
  
      Rails.logger.info("✅ AddCitationJob: Citation complete for Item##{item_id}")
    rescue => e
      Rails.logger.error("❌ AddCitationJob failed for Item##{item_id}: #{e.message}")
      raise e 
    end
  end
  