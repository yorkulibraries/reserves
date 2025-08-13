# frozen_string_literal: true

class SearchController < ApplicationController
  include ApplicationHelper

  authorize_resource Request

  def index
    @query = q = params[:q]
    @type = params[:type]
    @search_type = params[:search_type].presence || 'all'
    @page = params[:page] || 1
  
    if @type == 'users'
      @users = search_users(q)
    else
      @requests = search_requests(q, @search_type, @page)
    end
  
    respond_to do |format|
      format.html
      format.js
    end
  end

  private

  def search_users(q)
    return User.active.all if q.blank?

    begin
      User.search(q)
    rescue StandardError
      User.active.all
    end
  end

  def search_requests(q, search_type = "all", page = 1)
    return Request.none if q.blank?
  
    item_request_ids = []
    course_request_ids = []
    direct_request_ids = []
  
    case search_type
    when "item"
      items = Item.search(
        q,
        fields: [
          { title: :word_start },
          { author: :word_start },
          { isbn: :word_start },
          { ils_barcode: :word_start },
          { other_isbn_issn: :word_start },
          { publisher: :word_start },
          { callnumber: :word_start }
        ],
        match: :word_start,
        load: false
      )
      item_request_ids = items.map { |i| i["request_id"] }.compact
  
    when "course"
      courses = Course.search(
        q,
        fields: [{ code: :text_middle }, { name: :word_start }, { instructor: :word_start }],
        match: :word_start,
        load: false
      )
      course_ids = courses.map { |c| c["id"].to_i }.compact
      course_request_ids = Request.where(course_id: course_ids).pluck(:id)
  
    when "request"
      requests = Request.search(where: { id: q.to_i },load: false)

      direct_request_ids = requests.map(&:id).compact
  
    when "all"
      items = Item.search(
        q,
        fields: %i[title^10 author isbn ils_barcode other_isbn_issn publisher callnumber],
        match: :word_start,
        load: false
      )
      item_request_ids = items.map { |i| i["request_id"] }.compact
  
      courses = Course.search(
        q,
        fields: [{ code: :text_middle }, { name: :word_start }, { instructor: :word_start }],
        match: :word_start,
        load: false
      )
      course_ids = courses.map { |c| c["id"].to_i }.compact
      course_request_ids = Request.where(course_id: course_ids).pluck(:id)
    end
  
    # Combine IDs and make sure they're unique
    request_ids = (item_request_ids + course_request_ids + direct_request_ids).uniq
  
    # Let ActiveRecord handle pagination — no array slicing
    @combined_requests = Request.where(id: request_ids)
                                .includes(:course, :requester)
                                .order(created_at: :desc, id: :desc)
                                .page(page)
                                .per(10)
  end  
  
end
