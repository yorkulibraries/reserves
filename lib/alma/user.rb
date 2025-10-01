require 'net/http'
require 'uri'
require 'json'
require Rails.root.join('app', 'models', 'setting.rb')
require_relative 'api_defaults'
module Alma
  class User
    extend Alma::ApiDefaults

    def self.find_by_primary_id(primary_id:)
      uri = URI("#{base_path}/users/#{primary_id}")
      response = perform_get_request(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)
      parse_json(response.body)
    rescue => e
      Rails.logger.error("Alma::User.find_by_primary_id(#{primary_id}) error: #{e.message}")
      nil
    end

    # ---- Efficient name search (brief view) ----
    def self.search_by_name(first_name:, last_name:, limit: 50)
      return [] if first_name.to_s.strip.empty? || last_name.to_s.strip.empty?

      # fielded query: last_name + first_name. Avoid quoting/encoding the ~ value itself.
      q = "last_name~#{last_name} AND first_name~#{first_name}"

      uri = URI("#{base_path}/users")
      uri.query = URI.encode_www_form({ "q" => q, "view" => "brief", "limit" => limit })

      resp = perform_get_request(uri)
      return [] unless resp.is_a?(Net::HTTPSuccess)

      parsed = parse_json(resp.body)
      Array(parsed["user"])
    rescue => e
      Rails.logger.error("Alma::User.search_by_name error: #{e.message}")
      []
    end

    def self.find_best_by_name(first_name:, last_name:)
      candidates = search_by_name(first_name:, last_name:, limit: 100)
      return { status: :none } if candidates.empty?
    
      norm = ->(s) { I18n.transliterate(s.to_s).downcase.gsub(/[^a-z\s\-]/, '').squeeze(' ').strip }
      nf = norm.call(first_name); nl = norm.call(last_name)
    
      scored = candidates.map do |u|
        uf = norm.call(u['first_name']); ul = norm.call(u['last_name'])
        score = 0
        score += 3 if ul == nl
        score += 3 if uf == nf
        score += 2 if ul == nl && uf.start_with?(nf)
        score += 1 if ul == nl && !uf.empty? && !nf.empty? && uf[0] == nf[0]
        roles = Array(u.dig('user_roles', 'user_role')).map { |r| r.dig('role_type','value').to_s.upcase }
        score += 2 if roles.include?('INSTRUCTOR')
        group = u.dig('user_group','value').to_s.upcase
        score += 1 if %w[FACULTY STAFF].include?(group)
        [u, score]
      end
    
      best_score = scored.map(&:last).max
      return { status: :none } if best_score.nil? || best_score <= 0
    
      best = scored.select { |_, s| s == best_score }.map(&:first)
      exact = best.select { |u| norm.call(u['first_name']) == nf && norm.call(u['last_name']) == nl }
      choice = exact.presence || best
    
      return { status: :ambiguous, candidates: choice } if choice.size > 1
      { status: :ok, user: choice.first }
    end    
     

    # 2) create new
    def self.create(payload)
      uri = URI("#{base_path}/users")
      http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      headers.each { |k,v| req[k] = v }
      req.body = payload.to_json
      resp = http.request(req)
      raise "Alma User creation failed: HTTP #{resp.code} - #{resp.body}" unless [200, 201].include?(resp.code.to_i)
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
