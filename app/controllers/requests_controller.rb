# frozen_string_literal: true

class RequestsController < ApplicationController
  before_action :set_request,
                only: %i[show edit update destroy change_status change_owner assign rollover
                         rollover_confirm archive]
  authorize_resource

  def index
    if current_user.admin?
      @requests = Request.all.limit(200)
    else
      redirect_to requests_user_url(current_user)
    end
  end

  def show
    # @admin_users = User.admin.active.where(location_id: @request.reserve_location.id, is_reserves_staff: true).to_a
    @admin_users = User.admin.active.where(is_reserves_staff: true).to_a
    @admin_users.push(current_user) unless @admin_users.include?(current_user)


  end

  def edit; end

  def update
    @request.audit_comment = 'Request Updated'
  
    # Optional: prevent duplicate request for the same course (excluding current)
    if (cid = params.dig(:request, :course_id)).present?
      if Request.where(course_id: cid).where.not(id: @request.id).exists?
        flash[:notice] = 'You already have a request for that course.'
        return redirect_to request_path(Request.find_by(course_id: cid))
      end
    end
  
    if (u = params.dig(:request, :user))
      @request.requester.update(office: u[:office], department: u[:department], phone: u[:phone])
    end
  
    old_alma_course_id = @request.alma_course_id
  
    if @request.update(request_params)
      if @request.saved_change_to_course_id?
        Alma::AlmaSync.sync_request(@request, current_user)
        Alma::Course.update_items_course_and_reading_list(@request.course, old_alma_course_id) if old_alma_course_id.present?
      end
      redirect_to @request, notice: 'Request was successfully updated.'
    else
      render :edit
    end
  end  
             

  def destroy
    @request.audit_comment = 'Request Deleted'
    @request.destroy
    respond_to do |format|
      format.html { redirect_to requests_url }
      format.json { head :no_content }
    end
  end

  ## ADDITIONAL ACTIONS ##
  def change_status
    status = params[:status]
    @request.audit_comment = "Request status changed to #{status}"

    notice = "Status changed to #{status}"
    case status
    when Request::OPEN
      # ret = @request.updates()
      if @request.assigned_to
        @request.audit_comment = "Request has been Re-opened, status changed to #{status} and request has been unassigned"
        @request.update(status: status)
        @request.update(assigned_to: nil)
        notice = "Status changed to #{status} and request has been unassigned"
      else
        @request.update(status: status)
      end
      RequestMailer.status_change(@request, current_user).deliver_later
    when Request::INPROGRESS
      @request.update(status: status, assigned_to_id: current_user.id)
      # RequestMailer.status_change(@request, current_user).deliver_later
    when Request::COMPLETED
      @request.update(status: status, completed_date: Date.today) if @request.status != Request::CANCELLED
      RequestMailer.status_change(@request, current_user).deliver_later
    when Request::CANCELLED
      if @request.status != Request::COMPLETED
        @request.status = status
        @request.cancelled_date = Date.today
        @request.save(validate: false)
      end
      # RequestMailer.status_change(@request, current_user).deliver_later
    when Request::REMOVED
      if @request.status != Request::OPEN
        @request.status = status
        @request.removed_at = Date.today
        @request.removed_by_id = current_user.id
        @request.save(validate: false)

        # RequestMailer.status_change(@request, current_user).deliver_later
      end
    else
      # nothing is changed
      notice = "Status hasn't changed"
    end

    if @request.errors.size.zero?
      redirect_to request_path(@request), notice: notice
    else
      render :edit, notice: 'There are required fields missing, please fill them in'
    end
  end

  def change_owner
    new_owner = User.find(params[:requester_id])
    @request.audit_comment = "Requester changed from #{@request.requester.name} to #{new_owner.name}"
    @request.requester = new_owner
    @request.save(validate: false)

    redirect_to request_path(@request)
  end

  def archive
    if @request.status == Request::COMPLETED

      if @request.alma_course_id.present? && @request.alma_reading_list_id.present?
        success = Alma::ReadingList.delete(
          course_id: @request.alma_course_id,
          reading_list_id: @request.alma_reading_list_id
        )
  
        if success
          Rails.logger.info("✅ Deleted Alma reading list for Request##{@request.id}")
        else
          Rails.logger.warn("⚠️ Could not delete Alma reading list for Request##{@request.id}")
        end
      end

      @request.status = Request::REMOVED
      @request.removed_at = Date.today
      @request.removed_by_id = current_user.id
      @request.audit_comment = "Request has been removed #{status}"
      @request.save(validate: false)
      # RequestMailer.status_change(@request, current_user).deliver_later
    end

    redirect_to request_path(@request), notice: 'Your item(s) will be removed from reserve and Alma.'
  end

  def assign
    id = params[:who]
    u = User.find_by_id(id)

    name = u.nil? ? 'Unassigned' : u.name
    @request.audit_comment = "Request assigned to #{name}"
    @request.update(assigned_to_id: id)
    redirect_to request_path(@request), notice: "Assigned to #{name}"
  end

  def rollover_confirm; end

  def rollover
    course_year = params[:rollover] ? params[:rollover][:course_year] : ''
    course_term = params[:rollover] ? params[:rollover][:course_term] : ''
    course_section = params[:rollover] ? params[:rollover][:course_section] : ''
    course_credits = params[:rollover] ? params[:rollover][:course_credits] : ''
    course_student_count = params[:rollover] ? params[:rollover][:course_student_count] : ''
    @new_request = @request.rollover(course_year, course_term, course_section, course_credits)
    @new_request.course.update(student_count: course_student_count)

    redirect_to edit_request_path(@new_request), notice: 'Your item(s) will be kept on reserve.'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_request
    @request = Request.find(params[:id])

    @items = @request.items.includes(:audits)
  
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

  # Never trust parameters from the scary internet, only allow the white list through.
  def request_params
    params.require(:request).permit(
      :requested_date, :reserve_start_date, :reserve_end_date, :status,
      :reserve_location_id, :reserve_location, :requester_email, :course_id
    )
  end    
end
