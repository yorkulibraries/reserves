class AlmaController < ApplicationController
    protect_from_forgery with: :exception
  
    def lookup
      mms = params[:mms_id].presence || params.dig(:alma, :mms_id)
      return render json: { error: "Blank MMS ID" }, status: :unprocessable_entity if mms.blank?
  
      bib = AlmaService.fetch_bib(mms)
      return render json: { error: "Not found" }, status: :not_found if bib.blank?
  
      render json: bib
    rescue => e
      Rails.logger.warn("Alma lookup failed for #{mms}: #{e.class} #{e.message}")
      if e.message.include?("Missing ALMA_API_KEY")
        render json: { error: "Alma API key not configured" }, status: :unprocessable_entity
      else
        render json: { error: "Lookup failed" }, status: :bad_gateway
      end
    end
  end
  