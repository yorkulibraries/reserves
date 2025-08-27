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
    @request = Request.new(request_params) 
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
  
    course_info_id = params.dig(:request, :course_info_id)

    if course_info_id.blank?
      flash.now[:alert] = 'Course cannot be empty'
      return render :step_one
    end
  
    typed_count_param = params.dig(:request, :course_attributes, :student_count)
    typed_count = typed_count_param.to_s.gsub(/[^\d]/, '') # keep digits only
    typed_count = typed_count.presence&.to_i
  
    course = ensure_course_from_info!(course_info_id, student_count: typed_count)
    unless course
      flash.now[:alert] = 'Course not found. Please select a valid course.'
      return render :step_one
    end

    @request.course_id = course.id

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

  def ensure_course_from_info!(course_info_id, student_count: nil)
    info = CourseInfo.find_by(id: course_info_id)
    return nil unless info
  
    parts = parts_from_info(info)
    code  = build_code_from_info(parts, info.instructor_name)
    course = Course.find_or_initialize_by(code: code)
    puts 'info.course_number111'
    puts info.course_number
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
      puts 'info.course_number222'
      puts info.course_number

      puts 'course.course_number111'
      puts course.course_number
      course.audit_comment = "Created from CourseInfo #{info.id}"
      course.save!
      puts 'course.course_number2222'
      puts course.course_number
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
    year    = info.academic_year.to_s.split('-').first # supports "2024-2025"
    section = info.section.to_s.upcase
  
    { faculty:, subject:, number:, credits:, section:, term:, year: }
  end

  def build_code_from_info(p, instructor_name = nil)
    base = [p[:year], p[:faculty], p[:subject], p[:term], p[:number]].join('_') + "__#{p[:credits]}_#{p[:section]}"
    token = instructor_name.to_s.gsub(/\s+/, "")
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
      :student_count
    )
  end
end
