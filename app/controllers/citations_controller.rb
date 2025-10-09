class CitationsController < ApplicationController
  protect_from_forgery with: :exception

  def parse
    citation = params[:citation].to_s.strip
    return render json: { error: "Blank citation" }, status: :unprocessable_entity if citation.blank?

    entry  = AnyStyleService.parse(citation)
    mapped = CitationMapper.new(entry).to_item_attributes
    mapped[:author] = fallback_author(citation) if mapped[:author].blank?
    mapped[:raw_citation] = citation

    render json: mapped
  rescue => e
    Rails.logger.error("[AnyStyle] parse error: #{e.class}: #{e.message}")
    render json: { error: "Could not parse citation" }, status: :unprocessable_entity
  end

  private

  def fallback_author(raw)
    return if raw.blank?

    lead = raw.strip.sub(/\A["']/, "") # drop leading quote if present
    match = lead.match(/\A([^(\n]+?)\s*\(/)
    return unless match

    candidate = match[1].strip
    candidate = candidate.gsub(/[[:space:]]+/, " ")
    candidate = candidate.gsub(/\s*[:;,.]\z/, "") # trim trailing punctuation commonly after author segment

    candidate.presence
  end
end
  
