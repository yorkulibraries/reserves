# frozen_string_literal: true

class RequestWizardController < ApplicationController
  before_action :set_request, only: %i[step_two finish]
  authorize_resource :request

  def step_one
    if current_user.valid?
      @request = Request.new(status: Request::INCOMPLETE)
      @request.course = Course.new
      @request.requester = current_user    
    else
      redirect_to edit_user_path(current_user)
    end
  end

  def get_request_duplicated
    Request.includes(:course).find_by(course: {code: @request.course.code})
  end

  def save
    @request = Request.new(request_params) # <- includes :course_id directly
    @request.status       = Request::INCOMPLETE
    @request.requester_id = current_user.id
    @request.audit_comment = 'Request Step One Completed'
  
    # persist user's contact edits (best-effort, don't block Step 1)
    if params.dig(:request, :user)
      current_user.update(
        office:     params[:request][:user][:office],
        department: params[:request][:user][:department],
        phone:      params[:request][:user][:phone]
      )
    end
  
    if @request.course_id.blank?
      flash.now[:alert] = 'Course cannot be empty'
      return render :step_one
    end
  
    course = Course.find_by(id: @request.course_id)
    unless course
      flash.now[:alert] = 'Course not found. Please select a valid course.'
      return render :step_one
    end
  
    if (existing = Request.find_by(course_id: course.id))
      return redirect_to new_request_step_two_path(existing),
                         notice: 'Proceeding to Step 2.'
    end

    if @request.save
      begin
        Alma::AlmaSync.sync_request(@request, current_user)
      rescue => e
        Rails.logger.warn("Alma sync failed: #{e.message}")
      end
      redirect_to new_request_step_two_path(@request), notice: 'Proceeding to Step 2.'
    else
      render :step_one
    end
  end  

  def step_two
    @items = @request.items.recent_first # if any

    @notes = {}

    @items.each do |item|
      @notes[item.id] = Audited::Audit.where(
        auditable_id: @request.id,
        auditable_type: "Request",
        associated_id: item.id,
        associated_type: "item",
        action: "note"
      )
    end
  end

  def finish
    if @request.items.where.not(status: 'deleted').exists?
      @request.audit_comment = 'Request Step Two Completed'
      @request.status = Request::OPEN
      @request.requested_date = Date.today.to_date
  
      if @request.save
        RequestMailer.status_change(@request, current_user).deliver_later
        redirect_to @request
  
      else
        redirect_to edit_request_path(@request), alert: 'There are fields missing in this request'
      end
  
    else
      redirect_to new_request_step_two_path(@request),
                  alert: 'You must add at least one active item for this request to be submitted!'      
    end
  end
  

  #### PRIVATE METHODS ###
  private 

  def set_request
    @request = Request.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def request_params
    params.require(:request).permit(
      :requested_date,
      :reserve_start_date,
      :reserve_end_date,
      :status,
      :reserve_location_id,
      :reserve_location,
      :requester_email,
      :course_id
    )
  end
end
