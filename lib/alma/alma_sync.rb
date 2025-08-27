require 'net/http'
require 'uri'
require 'json'
require_relative 'api_defaults'
module Alma
  class AlmaSync
    extend ApiDefaults 
    # Called once after Step 1 (request saved)
    # Ensures both the Alma course and reading list exist, and
    # then stores their IDs back on the Request record.
    def self.sync_request(request, user)
      course = ::Course.find_by(id: request.course_id)

      unless course
        Rails.logger.error("❌ Request##{request.id} has no Course##{request.course_id}")
        return
      end

      instructor_id = course.alma_instructor_id

      if instructor_id.blank?
        instructor_id = create_or_find_instructor(course)
        course.update_column(:alma_instructor_id, instructor_id) if instructor_id
      end
    

      alma_code = alma_course_code_for(course)
      list_name = reading_list_name_for(course) 
      ac = Alma::Course.find_by_code(alma_code)
      unless ac
        ac = Alma::Course.create(
          "code"                   => alma_code,
          "name"                   => course.name,
          "status"                 => "ACTIVE",
          "processing_department"  => { "value" => "YOR_CR", "desc" => "York University Course Reserves" },
          "start_date"             => Date.today.strftime("%Y-%m-%d"),
          "end_date"               => "2099-12-31",
          "note"                   => [{ "value" => "Created by #{user.email} via Reserves app" }],
          "instructor"             => [ { "primary_id" => instructor_id } ]
        )
        Rails.logger.info("✅ Created Alma course #{alma_code} (ID #{ac['id']})")
      end
      request.update_column(:alma_course_id, ac["id"])

      rl = ReadingList.find_by_name(ac["id"], list_name)
      unless rl
        rl = ReadingList.create(
          course_id:   ac["id"],
          name:        list_name,
          description: "Auto-generated from Reserves app"
        )
        Rails.logger.info("✅ Created Alma reading-list #{list_name} (ID #{rl['id']})")
      end
      request.update_column(:alma_reading_list_id, rl["id"])
    rescue => e
      Rails.logger.error("❌ AlmaSync.sync_request(Req##{request.id}) error: #{e.message}")
    end


    def self.sync_item(item, user)
      req = item.request
      Rails.logger.debug("alma_course_id type: #{req.alma_course_id.class}, value: #{req.alma_course_id}")
      Rails.logger.debug("alma_reading_list_id type: #{req.alma_reading_list_id.class}, value: #{req.alma_reading_list_id}")

      course_id = req.alma_course_id
      list_id   = req.alma_reading_list_id

      if course_id.blank? || list_id.blank?
        Rails.logger.error("❌ Cannot cite Item##{item.id}: missing alma_course_id or alma_reading_list_id on Request##{req.id}")
        return
      end

      alma_type = item.item_type == "multimedia" ? "VM" : "BK"
      citation_data = {
        "type" => {
            "value" => alma_type
        },
        "link" => "",
        "status" => {
            "value" => "BeingPrepared"
        },
        "copyrights_status" => {
            "value" => "NOTDETERMINED"
        },
        "secondary_type" => {
            "value" => alma_type
        },
        "metadata" => {
            "title"                => item.title,
            "author"               => item.author,
            "publisher"            => item.publisher,
            "publication_date"     => item.publication_date,
            "edition"              => "",
            "isbn"                 => item.isbn,
            "call_number"          => item.callnumber,
            "year"                 => item.publication_date
        },
        "defined_fields"  => {
            "type_attributes" => {
            "attribute"      => { "value" => item.item_type },
            "attribute_type" => { "value" => "Requested_format" }
            }
        }
      }

      result = ReadingList.add_citation(
        course_id:       course_id,
        reading_list_id: list_id,
        citation_data:   citation_data
      )

      if result
        item.update_column(:alma_citation_id, result["id"] || result.dig("citation", "id"))
        Rails.logger.info("✅ Citation created for Item##{item.id}")
      else
        Rails.logger.warn("⚠️ Citation FAILED for Item##{item.id} on RL##{list_id}")
      end

      unless result
        Rails.logger.warn("⚠️ Citation FAILED for Item##{item.id} on RL##{list_id}")
      end
    rescue => e
      Rails.logger.error("❌ AlmaSync.sync_item(Item##{item.id}) error: #{e.message}")
    end

    private

    def self.alma_course_code_for(course)
      subject = course.code_subject.to_s.upcase
      number  = (course.course_number.presence || course.code.to_s[/_(.+?)__/, 1]).to_s
      "#{subject}#{number}"
    end

    def self.reading_list_name_for(course)
      base = alma_course_code_for(course)
      instr = course.instructor.to_s.delete(" ")
      "#{base}_#{instr}".slice(0, 50)
    end

    def self.create_or_find_instructor(course)
      raw_name = course.instructor.to_s
      clean_name = raw_name.gsub(/[^A-Za-z\s]/, '').strip.gsub(/\s+/, ' ')
      parts = clean_name.split(' ')
      first_name = parts.first || ''
      last_name = parts[1..].join(' ') || ''
      primary_id = clean_name.delete(' ').upcase

      alma_instructor = User.find_by_primary_id(primary_id: primary_id)
      if alma_instructor.nil?
        alma_instructor = User.find_by_name(first_name: first_name, last_name: last_name)
      end
      
      if alma_instructor.nil?
        payload = {
          "record_type" => { "value" => "CONTACT" },
          "first_name" => first_name,
          "last_name" => last_name,
          "user_group" => { "value" => "FACULTY" },
          "account_type" => { "value" => "INTERNAL" }
        }
        alma_instructor = User.create(payload)
        Rails.logger.info("✅ Created Alma instructor #{primary_id}")
      else
        Rails.logger.info("✅ Found existing Alma instructor")
      end

      alma_instructor["primary_id"] || alma_instructor["id"]
    rescue => e
      Rails.logger.error("❌ create_or_find_instructor failed: #{e.message}")
      nil
    end

    def self.perform_get_request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.request_uri)
      headers.each { |k,v| req[k] = v }
      http.request(req)
    end

    def self.parse_json(body)
      JSON.parse(body)
    end
  end
end
