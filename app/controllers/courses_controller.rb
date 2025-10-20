# frozen_string_literal: true

class CoursesController < ApplicationController
  before_action :set_course, only: %i[show edit update destroy]
  authorize_resource

  # GET /courses
  # GET /courses.json
  def index
    @courses = Course.all.page(params[:page]).per(100)
  end

  # GET /courses/1
  # GET /courses/1.json
  def show; end

  # GET /courses/new
  def new
    @course = Course.new
  end

  # GET /courses/1/edit
  def edit; end

  # POST /courses
  # POST /courses.json
  def create
    @course = Course.new(course_params)
    @course.audit_comment = "Created a course #{@course.name}"
    respond_to do |format|
      if @course.save
        format.html { redirect_to courses_path, notice: 'Course was successfully created.' }
        format.json { render action: 'show', status: :created, location: @course }
      else
        format.html { render action: 'new' }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /courses/1
  # PATCH/PUT /courses/1.json
  def update
    @course.audit_comment = "Updated course #{@course.name}"
    respond_to do |format|
      if @course.update(course_params)
        format.html { redirect_to courses_path, notice: 'Course was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  def autocomplete
    academic_start = Date.today.month < 9 ? Date.today.year - 1 : Date.today.year
    allowed_years  = [academic_start.to_s, (academic_start + 1).to_s]

    term = params[:term].to_s.strip
    courses = CourseInfo.search(
      term,
      fields: %i[
        subject_abrev subject course_number course_title instructor_name faculty_abrev faculty_short
      ],
      match:  :word_start,
      where:  { academic_year: allowed_years },
      load:   true,
      limit:  100
    )

    render json: courses.map { |c|
      parts = info_parts(c)
      credits = parts[:credits].to_s.include?('.') ? parts[:credits] : "#{parts[:credits]}.00"
      
      {
        label: build_label(c, parts),
        value: c.id,
        code:  build_code_from_info(c, parts),
        instructor: display_instructor(c.instructor_name),
        title: c.course_title,
        faculty: parts[:faculty],
        subject: parts[:subject],
        number: parts[:number],
        credits: credits,
        section: parts[:section],
        term: parts[:term],
        year: parts[:year]
      }

    }
  end

  # DELETE /courses/1
  # DELETE /courses/1.json
  def destroy
    @course.audit_comment = "Removed course #{@course.name}"
    @course.destroy
    respond_to do |format|
      format.html { redirect_to courses_url }
      format.json { head :no_content }
    end
  end

  private

  # Build the same “parts” hash previously from parse_code(c.code)
  # Keys: :faculty, :subject, :number, :credits, :section, :term, :year
  def info_parts(info)
    faculty = (info.faculty_abrev.presence || info.faculty_short.presence || info.faculty).to_s.upcase.gsub(/[^A-Z]/, '')
    subject = (info.subject_abrev.presence || info.subject).to_s.upcase.gsub(/[^A-Z]/, '')
    number  = info.course_number.to_s.upcase
    credit_value = info.credit.presence || '0'
    credits = Course.normalize_code_credit(credit_value)
    {
      faculty: faculty,
      subject: subject,
      number:  number,
      credits: credits,
      section: info.section.to_s.upcase,
      term:    normalize_term(info.study_session),
      year:    info.academic_year.to_s
    }
  end

  def build_label(course, p)
    if p.present?
      credits = p[:credits].to_s.include?('.') ? p[:credits] : "#{p[:credits]}.00"
      instructor = display_instructor(course.instructor_name)

      # [course title] [faculty]/[subject] [course_number] [credits] [section] [instructor name]
      # Example: "Independent Study, HH/GH 4000 3.00, A, Amrita Daftary"
      "#{course.course_title}, #{p[:faculty]}/#{p[:subject]} #{p[:number]} #{credits}, #{p[:section]}, #{instructor}"
    else
      instructor = display_instructor(course.instructor_name)
      "#{course.course_title}, #{course.code}, #{instructor}"
    end
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

  def build_code_from_info(info, p)
    return nil if p.blank?
    [p[:year], p[:faculty], p[:subject], p[:term], p[:number]].join('_') + "__#{p[:credits]}_#{p[:section]}"
  end

  def display_instructor(name)
    n = name.to_s.gsub(/\s*,\s*/, ', ').squeeze(' ').strip
    if n.include?(',')
      last, first = n.split(',', 2).map(&:strip)
      [first, last].reject(&:blank?).join(' ')
    else
      n
    end
  end
  
  # Use callbacks to share common setup or constraints between actions.
  def set_course
    @course = Course.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def course_params
    params.require(:course).permit(:name, :code, :student_count, :instructor, :course_number, :year, :faculty, :subject, :term, :section, :credits)
  end
end
