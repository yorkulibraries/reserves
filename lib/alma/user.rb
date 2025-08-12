require 'net/http'
require 'uri'
require 'json'
require Rails.root.join('app', 'models', 'setting.rb')
require_relative 'api_defaults'
module Alma
  class User
    extend Alma::ApiDefaults

    def self.get_all_instructors
      results = []
      offset = 0
      limit = 100
    
      loop do
        uri = URI("#{base_path}/users")
        uri.query = URI.encode_www_form({
          user_type: 'Instructor',
          view: 'full',
          limit: limit,
          offset: offset
        })
    
        response = perform_get_request(uri)
        parsed = parse_json(response.body)
    
        break unless parsed["user"]&.any?
    
        results.concat(parsed["user"])
        offset += limit
      end
    
      results
    end
     


    def self.find_by_primary_id(primary_id:)
      uri = URI("#{base_path}/users/#{primary_id}")
      response = perform_get_request(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)
    
      result = parse_json(response.body)
      Rails.logger.debug("Alma user fetched: #{result.inspect}")
      result
    rescue => e
      Rails.logger.error("Alma::User.find_by_primary_id(#{primary_id}) error: #{e.message}")
      nil
    end  
     

    # 2) create new
    def self.create(payload)
      uri = URI("#{base_path}/users")
      http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      headers.each { |k,v| req[k] = v }
      req.body = payload.to_json
      resp = http.request(req)
    
      unless [200,201].include?(resp.code.to_i)
        raise "Alma User creation failed: HTTP #{resp.code} - #{resp.body}"
      end
    
      parse_json(resp.body)
    end

    def self.find_by_name(first_name:, last_name:)
      name = "#{first_name} #{last_name}"
      encoded_name = URI.encode_www_form_component(name) 
    
      uri = URI("#{base_path}/users")
      uri.query = URI.encode_www_form({
        "q"     => "name~\"#{encoded_name}\"", 
        "view"  => "full",
        "limit" => 25
      })
      
      response = perform_get_request(uri)
    
      parsed = parse_json(response.body)

      if parsed["user"].present?
        users = parsed["user"].select do |u|
          u["first_name"] == first_name && u["last_name"] == last_name
        end
    
        if users.any?
          return users
        else
          Rails.logger.error("No matching user found for #{first_name} #{last_name}")
          return nil
        end
      else
        Rails.logger.error("No users found in the response")
        return nil
      end
    end             
  end
end
