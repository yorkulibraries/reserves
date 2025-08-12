require 'net/http'
require 'uri'
require 'json'
require_relative 'api_defaults'
module Alma
  class ReadingList
    extend Alma::ApiDefaults

    def self.create(course_id:, name:, description:)
        uri = URI("#{base_path}/courses/#{course_id}/reading-lists")
        payload = {
          "code"        => name,         
          "name"        => name,
          "description" => description,
          "status"      => {
            "value" => "BeingPrepared",
            "desc"  => "Being Prepared"  
          },
          "due_back_date" => "2099-12-31"
        }
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
      
        request = Net::HTTP::Post.new(uri.request_uri)
        headers.each { |key, value| request[key.to_s] = value }
        request.body = payload.to_json
        
        response = http.request(request)
      
        if [200, 201].include?(response.code.to_i)
          parse_json(response.body)
        else
          raise StandardError, "Alma Reading List creation failed: #{response.body}"
        end
      rescue StandardError => e
        Rails.logger.error("Alma::ReadingList.create failed: #{e.message}")
        nil 
    end      

    def self.add_citation(course_id:, reading_list_id:, citation_data:)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists/#{reading_list_id}/citations")
      puts 'uri'
      puts uri
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      headers.each { |key, value| request[key.to_s] = value }
      request.body = citation_data.to_json

      response = http.request(request)

      if [200, 201].include?(response.code.to_i)
        parse_json(response.body)
      else
        raise StandardError, "Alma Citation creation failed: #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error("Alma::ReadingList.add_citation failed: #{e.message}")
      nil
    end

    def self.find_by_name(course_id, list_name)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists")
      uri.query = URI.encode_www_form(limit: 50, offset: 0, status: 'ALL')

      response = perform_get_request(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      lists = parse_json(response.body)["reading_list"] || []
      lists.find { |rl| rl["name"] == list_name }
    rescue => e
      Rails.logger.error("Alma::ReadingList.find_by_name failed: #{e.message}")
      nil
    end

    def self.delete_citation(course_id:, reading_list_id:, citation_id:)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}")
      http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true
      req  = Net::HTTP::Delete.new(uri.request_uri)
      headers.each { |k,v| req[k] = v }
      resp = http.request(req)
      return true if resp.code.to_i == 204 || resp.code.to_i == 200
      raise "Delete failed: #{resp.body}"
    rescue => e
      Rails.logger.error("Alma::ReadingList.delete_citation failed: #{e.message}")
      false
    end

    def self.get_items_for_reading_list(course_id, reading_list_id)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists/#{reading_list_id}/citations")
      response = perform_get_request(uri)

      if response.is_a?(Net::HTTPSuccess)
        parsed = parse_json(response.body)
        parsed["citation"] || [] 
      else
        Rails.logger.error("❌ Failed to retrieve citations...")
        []
      end
    rescue => e
      Rails.logger.error("Alma::ReadingList.get_items_for_reading_list failed: #{e.message}")
      [] 
    end

    def self.get_reading_list_for_course(course_id)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists")
      response = perform_get_request(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        parsed_response = parse_json(response.body)
        
        reading_list = parsed_response["reading_list"]&.first
        return reading_list ? reading_list["id"] : nil
      else
        Rails.logger.error("❌ Failed to retrieve reading list for Course ID: #{course_id}")
        return nil
      end
    end

    def self.generate_reading_list_name(course:, instructor:)
        code = course.code
        instructor_name = instructor.to_s.strip.gsub(/\s+/, '_').gsub(/["',;\.\-–—]/, '') 
        "#{code}_#{instructor_name}".truncate(100)
    end      

    def self.get_citation(course_id, reading_list_id, citation_id)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}")
      response = perform_get_request(uri)
      return parse_json(response.body) if response.is_a?(Net::HTTPSuccess)
    
      Rails.logger.error("❌ Failed to fetch citation #{citation_id} from RL #{reading_list_id}: #{response.body}")
      nil
    end    

    def self.delete(course_id:, reading_list_id:)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists/#{reading_list_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Delete.new(uri.request_uri)
      headers.each { |k, v| req[k] = v }
    
      res = http.request(req)
      res.is_a?(Net::HTTPSuccess)
    rescue => e
      Rails.logger.error("❌ Alma::ReadingList.delete failed: #{e.message}")
      false
    end
  end
end
