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

      return { status: :error, citations: [] } unless response

      if response.is_a?(Net::HTTPSuccess)
        parsed = parse_json(response.body)
        { status: :ok, citations: parsed["citation"] || [] }
      else
        code = response.code.to_i
        body_text = response.body.to_s
        if code == 404 || (code == 400 && body_text.downcase.include?('not') && body_text.downcase.include?('found') && body_text.downcase.include?('course'))
          Rails.logger.error("❌ Reading list #{reading_list_id} for Course #{course_id} not found in Alma (#{code})")
          { status: :not_found, citations: [] }
        else
          Rails.logger.error("❌ Failed to retrieve citations for Course #{course_id}, List #{reading_list_id}: #{response.code} #{response.body}")
          { status: :error, citations: [] }
        end
      end
    rescue => e
      Rails.logger.error("Alma::ReadingList.get_items_for_reading_list failed: #{e.message}")
      { status: :error, citations: [] }
    end

    def self.get_reading_list(course_id:, reading_list_id:)
      uri = URI("#{base_path}/courses/#{course_id}/reading-lists/#{reading_list_id}")
      response = perform_get_request(uri)

      if response.is_a?(Net::HTTPSuccess)
        { status: :ok, data: parse_json(response.body) }
      elsif response&.code.to_i == 404
        Rails.logger.error("❌ Reading list #{reading_list_id} for Course #{course_id} not found in Alma (404)")
        { status: :not_found, data: nil }
      else
        Rails.logger.error("❌ Failed to fetch reading list #{reading_list_id} for Course #{course_id}: #{response&.code} #{response&.body}")
        { status: :error, data: nil }
      end
    rescue => e
      Rails.logger.error("Alma::ReadingList.get_reading_list failed: #{e.message}")
      { status: :error, data: nil }
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
