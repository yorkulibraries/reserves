require 'net/http'
require 'uri'
require 'json'
require_relative 'api_defaults'
module Alma
  class Course
    extend ApiDefaults

    def self.find(course_id:)
      uri = URI("#{base_path}/courses/#{course_id}")
      response = perform_get_request(uri)
    
      return nil unless response.is_a?(Net::HTTPSuccess)
    
      new(parse_json(response.body))
    rescue StandardError => e
      Rails.logger.error("Alma::Course.find failed for ID #{course_id}: #{e.message}")
      nil
    end

    def self.find_by_code(code)
      uri = URI("#{base_path}/courses")
    

      query_params = {
        q:            "code~#{code}",
        offset:       0,
        status:       "ALL",
        order_by:     "code,section",
        direction:    "ASC",
        exact_search: "false"
      }
      uri.query = URI.encode_www_form(query_params)
    
      response = perform_get_request(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)
    
      parsed = parse_json(response.body)
      #Rails.logger.debug("Alma::Course.find_by_code(#{code.inspect}) → parsed: #{parsed.inspect}")
    

      parsed["course"]&.find { |c| c["code"] == code }
    rescue StandardError => e
      Rails.logger.error("Alma::Course.find_by_code failed for code #{code}: #{e.message}")
      nil
    end
    

    def self.create(course_data)
      uri = URI("#{base_path}/courses")
      response = perform_post_request(uri, course_data)

      if [200, 201].include?(response.code.to_i)
        new(parse_json(response.body))
      else
        raise StandardError, "Alma Course creation failed: #{response.body}"
      end
    end
      
    def self.get_items_for_course(course_id)
      reading_list_id = Alma::ReadingList::get_reading_list_for_course(course_id)

      if reading_list_id.nil?
        Rails.logger.error("❌ No reading list found for Course ID: #{course_id}")
        return []
      end

      result = Alma::ReadingList.get_items_for_reading_list(course_id, reading_list_id)
      result ? result[:citations] : []
    end

    def self.update_items_course_and_reading_list(new_course, old_alma_course_id)
      new_course_in_alma = Alma::Course.find_by_code(new_course.code)
      unless new_course_in_alma
        Rails.logger.info("❌ Course #{new_course.code} does not exist in Alma. Creating new course...")
        new_course_in_alma = Alma::Course.create(
          "code"                   => new_course.code,
          "name"                   => new_course.name,
          "status"                 => "ACTIVE",
          "processing_department"  => { "value" => "YOR_CR", "desc" => "York University Course Reserves" },
          "start_date"             => Date.today.strftime("%Y-%m-%d"),
          "end_date"               => "2099-12-31",
          "note"                   => [{ "value" => "Created by Reserves app" }],
          "instructor"             => [{ "primary_id" => new_course.alma_instructor_id }]
        )
      end
    
      old_reading_list_id = Alma::ReadingList.get_reading_list_for_course(old_alma_course_id)
      new_reading_list_id = Alma::ReadingList.get_reading_list_for_course(new_course_in_alma["id"])
    
      if old_reading_list_id.nil? || new_reading_list_id.nil?
        Rails.logger.error("❌ Could not find reading lists for one or both courses (old: #{old_alma_course_id}, new: #{new_course_in_alma['id']})")
        return
      end
    

      old_items_result = Alma::ReadingList.get_items_for_reading_list(old_alma_course_id, old_reading_list_id)
      old_course_items = old_items_result ? old_items_result[:citations] : []
    
      if old_course_items.blank?
        Rails.logger.warn("ℹ️ No items found to copy from old course (#{old_alma_course_id})")
        return
      end
    
      old_course_items.each do |item|

        full_citation = Alma::ReadingList.get_citation(old_alma_course_id, old_reading_list_id, item["id"])
        unless full_citation
          Rails.logger.error("❌ Could not fetch details for citation #{item['id']}")
          next
        end
    

        clean_citation = full_citation.except(
          "id", "link", "created_date", "last_modified_date",
          "citation_origin", "metadata_source"
        )
    

        result = Alma::ReadingList.add_citation(
          course_id: new_course_in_alma["id"],
          reading_list_id: new_reading_list_id,
          citation_data: clean_citation
        )
    
        if result
          Rails.logger.info("✅ Copied citation #{item['id']} to new list (new citation #{result['id']})")
    

          if Alma::ReadingList.delete_citation(
            course_id: old_alma_course_id,
            reading_list_id: old_reading_list_id,
            citation_id: item["id"]
          )
            Rails.logger.info("🗑️ Deleted citation #{item['id']} from old list")
          else
            Rails.logger.warn("⚠️ Failed to delete citation #{item['id']} from old list")
          end
        else
          Rails.logger.error("❌ Failed to copy citation #{item['id']} to new list")
        end
      end
      # delete old reading list if now empty
      remaining_result = Alma::ReadingList.get_items_for_reading_list(old_alma_course_id, old_reading_list_id)
      remaining = remaining_result ? remaining_result[:citations] : []
      if remaining.blank?
        if Alma::ReadingList.delete(course_id: old_alma_course_id, reading_list_id: old_reading_list_id)
          Rails.logger.info("🧹 Deleted old reading list #{old_reading_list_id}")
        else
          Rails.logger.warn("⚠️ Tried to delete old reading list #{old_reading_list_id} but Alma refused")
        end
      else
        Rails.logger.info("📚 Old reading list #{old_reading_list_id} not empty (#{remaining.size} left). Not deleting.")
      end
    end
  end
end
