# frozen_string_literal: true

class SearchController < ApplicationController
  include ApplicationHelper

  authorize_resource Request

  def index
    @query = q = params[:q]
    @type = params[:type]
    @search_type = params[:search_type].presence || 'all'

    if @type == 'users'
      @users = search_users(q)
    else
      @requests = search_requests(q, @search_type)
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
  
    item_requests = Request.none
    course_requests = Request.none
    requests = Request.none

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
        match: :word_start
      )
      item_request_ids = items.map(&:request_id).compact
      item_requests = item_request_ids.any? ? Request.where(id: item_request_ids) : Request.none
  
    when "course"
      courses = Course.search(
        q,
        fields: [{ code: :text_middle }, { name: :word_start }, { instructor: :word_start }],
        match: :word_start
      )
      course_ids = courses.map(&:id).compact
      course_requests = course_ids.any? ? Request.where(course_id: course_ids) : Request.none

    when "request"
      #q = params[:q].to_s
      requests = Request.search(where: { id: q.to_i })
      
      request_ids = requests.map(&:id).compact
      requests = request_ids.any? ? Request.where(id: request_ids) : Request.none

      
    when "all"
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
        match: :word_start
      )
      item_request_ids = items.map(&:request_id).compact
      item_requests = item_request_ids.any? ? Request.where(id: item_request_ids) : Request.none
      
      courses = Course.search(
        q,
        fields: [{ code: :text_middle }, { name: :word_start }, { instructor: :word_start }],
        match: :word_start
      )
  
      course_ids = courses.map(&:id).compact
      course_requests = course_ids.any? ? Request.where(course_id: course_ids) : Request.none
    end
  
    @combined_requests = (course_requests.to_a + item_requests.to_a + requests.to_a).uniq
  
    @combined_requests = Kaminari.paginate_array(@combined_requests, total_count: @combined_requests.size).page(page).per(10)
  end
end
