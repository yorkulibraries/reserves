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
    @admin_users = User.admin.active.where(is_reserves_staff: true).to_a
    @admin_users.push(current_user) unless @admin_users.include?(current_user)
  end

  def edit; end

  def update
    @request.audit_comment = 'Request Updated'

    if (u = params.dig(:request, :user))
      @request.requester.update(office: u[:office], department: u[:department], phone: u[:phone])
    end

    if (course_info_id = params.dig(:request, :course_info_id)).present?
      typed_count_param = params.dig(:request, :course_attributes, :student_count) || params.dig(:request, :student_count)
      typed_count = typed_count_param.to_s.gsub(/[^\d]/, '').presence&.to_i

      course = ensure_course_from_info!(course_info_id, student_count: typed_count)
      unless course
        flash.now[:alert] = 'Course not found. Please select a valid course.'
        return render :edit
      end

      if (existing = Request.find_by(course_id: course.id)) && existing.id != @request.id
        return redirect_to new_request_step_two_path(existing), notice: 'Proceeding to Step 2.'
      end

      @request.course_id = course.id
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
    when Request::COMPLETED
      @request.update(status: status, completed_date: Date.today) if @request.status != Request::CANCELLED
      RequestMailer.status_change(@request, current_user).deliver_later
    when Request::CANCELLED
      if @request.status != Request::COMPLETED
        @request.status = status
        @request.cancelled_date = Date.today
        @request.save(validate: false)
      end
    when Request::REMOVED
      if @request.status != Request::OPEN
        @request.status = status
        @request.removed_at = Date.today
        @request.removed_by_id = current_user.id
        @request.save(validate: false)
      end
    else
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

  def set_request
    @request = Request.find(params[:id])
  
    if @request.alma_course_id.present? && @request.alma_reading_list_id.present?
      begin
        result = Alma::ReadingListSync.sync!(request_id: @request.id, actor_id: current_user.id)
  
        if result[:added_local].to_i > 0
          #flash.now[:notice] = "New Items found. Synced items with Alma."
          flash.now[:notice] = "New Items found. Synced #{result[:added_local]} item(s) with Alma."
        end
  
        if result[:failed_local].to_i > 0
          flash.now[:alert] = "#{result[:failed_local]} item(s) failed to sync from Alma and were skipped."
        end
      rescue => e
        Rails.logger.error("❌ Inline Alma sync failed for Request##{@request.id}: #{e.class}: #{e.message}")
        flash.now[:alert] = 'Alma sync failed; displaying existing items.'
      end
    end
  
    @items = @request.items.includes(:audits)
    @notes = {}
    @items.each do |item|
      @notes[item.id] = Audited::Audit.where(
        auditable_id: @request.id,
        auditable_type: 'Request',
        associated_id: item.id,
        associated_type: 'item',
        action: 'note'
      )
    end
  end

  def request_params
    params.require(:request).permit(
      :requested_date,
      :reserve_start_date,
      :reserve_end_date,
      :status,
      :reserve_location_id,
      :reserve_location,
      :requester_email,
      :student_count
    )
  end

  def ensure_course_from_info!(course_info_id, student_count: nil)
    info = CourseInfo.find_by(id: course_info_id)
    return nil unless info

    parts = parts_from_info(info)
    code  = build_code_from_info(parts, info.instructor_name)
    course = Course.find_or_initialize_by(code: code)
    if course.new_record?
      course.assign_attributes(
        name:          info.course_title.presence || info.course_title1,
        instructor:    info.instructor_name.presence || 'TBA',
        course_number: info.course_number,
        year:          parts[:year],
        faculty:       parts[:faculty],
        subject:       parts[:subject],
        term:          parts[:term],
        section:       parts[:section],
        credits:       parts[:credits],
        student_count: student_count || 0
      )
      course.audit_comment = "Created from CourseInfo #{info.id}"
      course.save!
    end
    course
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("ensure_course_from_info! failed: #{e.record.errors.full_messages.join(', ')}")
    nil
  end

  def parts_from_info(info)
    faculty = (info.faculty_abrev.presence || info.faculty_short.presence || info.faculty).to_s.upcase.gsub(/[^A-Z]/, '')
    subject = (info.subject_abrev.presence || info.subject).to_s.upcase.gsub(/[^A-Z]/, '')
    number  = info.course_number.to_s.upcase
    credits = info.credit.present? ? format('%.2f', info.credit.to_f) : '0.00'
    term    = normalize_term(info.study_session)
    year    = info.academic_year.to_s.split('-').first
    section = info.section.to_s.upcase
    { faculty:, subject:, number:, credits:, section:, term:, year: }
  end

  def build_code_from_info(p, instructor_name = nil)
    base  = [p[:year], p[:faculty], p[:subject], p[:term], p[:number]].join('_') + "__#{p[:credits]}_#{p[:section]}"
    token = instructor_name.to_s.gsub(/\s+/, '')
    token.present? ? "#{base}_#{token}" : base
  end

  def normalize_term(study_session)
    s = study_session.to_s.strip.upcase
    case s
    when 'FALL', 'F' then 'F'
    when 'WINTER', 'W' then 'W'
    when 'FALL/WINTER', 'FW', 'F/W' then 'FW'
    when 'Y', 'FULL YEAR' then 'Y'
    when 'SUMMER', 'SU', 'S' then 'SU'
    when 'S1', 'S2' then s
    else s.presence || 'F'
    end
  end
end