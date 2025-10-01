# frozen_string_literal: true

class Search::PrimoController < ApplicationController
  include ApplicationHelper

  authorize_resource Request

  def create
    @query = params[:q]
    @search_type = params[:type]

    finder = BibFinder.new
    @records = finder.search_primo(@query, 10, @search_type)
  rescue => e
    Rails.logger.warn("Primo search failed: #{e.class}: #{e.message}")

    respond_to do |format|
      format.js { render js: "window.dispatchEvent(new CustomEvent('primo:search-error', { detail: 'Primo search failed' }));", status: :bad_gateway }
      format.json { render json: { error: 'Primo search failed' }, status: :bad_gateway }
      format.html { render plain: 'Primo search failed', status: :bad_gateway }
    end
  end
end
