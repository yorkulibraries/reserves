# frozen_string_literal: true
require "net/http"
require "json"
require "cgi"

class AlmaService
  def self.config
    cfg    = Alma.respond_to?(:configuration) ? Alma.configuration : nil
    key    = cfg&.apikey.presence || (defined?(Setting) && Setting.alma_apikey).presence || ENV["ALMA_API_KEY"]
    region = cfg&.region.presence || (defined?(Setting) && Setting.alma_region).presence || ENV["ALMA_REGION"] || "na"

    host = ENV["ALMA_API_HOST"].presence || begin
      case region.to_s.downcase
      when "na" then "api-na.hosted.exlibrisgroup.com"
      when "ca" then "api-ca.hosted.exlibrisgroup.com"
      else           "api-na.hosted.exlibrisgroup.com"
      end
    end

    { key: key, host: host }
  end

  def self.fetch_bib(mms_id)
    cfg = config
    raise "Missing ALMA_API_KEY" if cfg[:key].blank?

    path = "/almaws/v1/bibs/#{CGI.escape(mms_id)}"
    query = "view=full&expand=record"
    uri  = URI::HTTPS.build(host: cfg[:host], path: path, query: query)

    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "apikey #{cfg[:key]}"
    req["Accept"]        = "application/json"

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15) { |h| h.request(req) }

    code = res.code.to_i
    raise "Alma #{code}" if code >= 400

    body = JSON.parse(res.body) rescue {}
    AlmaMarcExtractor.normalize_from_bib_json(body)
  end
end
