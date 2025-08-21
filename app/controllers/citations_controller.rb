class CitationsController < ApplicationController
    protect_from_forgery with: :exception
  
    def parse
      citation = params[:citation].to_s.strip
      return render json: { error: "Blank citation" }, status: :unprocessable_entity if citation.blank?
  
      entry  = AnyStyleService.parse(citation)
      mapped = CitationMapper.new(entry).to_item_attributes
      mapped[:raw_citation] = citation
  
      render json: mapped
    rescue => e
      Rails.logger.error("[AnyStyle] parse error: #{e.class}: #{e.message}")
      render json: { error: "Could not parse citation" }, status: :unprocessable_entity
    end
end
  