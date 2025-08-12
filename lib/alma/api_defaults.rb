require Rails.root.join('app', 'models', 'setting.rb')

module Alma
    module ApiDefaults

      def base_path
        "#{Setting.alma_region}/almaws/v1"
      end
  
      def headers
        {
          "Authorization" => "apikey #{Setting.alma_apikey}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }
      end
  
      def perform_get_request(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
  
        request = Net::HTTP::Get.new(uri.request_uri)
        headers.each { |key, value| request[key.to_s] = value }
  
        http.request(request)
      end
  
      def perform_post_request(uri, payload)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
  
        request = Net::HTTP::Post.new(uri.request_uri)
        headers.each { |key, value| request[key.to_s] = value }
        request.body = payload.to_json
  
        http.request(request)
      end

      def perform_put_request(uri, payload)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
      
        req = Net::HTTP::Put.new(uri.request_uri)
        headers.each { |k,v| req[k.to_s] = v }
        req.body = payload.to_json
      
        http.request(req)
      end
      

      def parse_json(body)
        JSON.parse(body)
      rescue JSON::ParserError => e
        raise "Invalid JSON response: #{e.message}"
      end
    end
  end
  