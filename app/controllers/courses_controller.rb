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

    courses = Course.search(
      params[:term],
      fields: [:code, :name],
      match:  :word_start,
      where:  { code_year: allowed_years },
      load:   false,
      limit:  100
    )

    render json: courses.map { |c|
      parts = parse_code(c.code)
      credits = parts[:credits].to_s.include?('.') ? parts[:credits] : "#{parts[:credits]}.00"

      {
        label: build_label(c, parts),
        value: c.id,
        code:  c.code,
        instructor: c.instructor,
        title: c.name,
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

  # Expected code examples:
  # 2024_GS_TRAN_FW_5700__3_A
  # 2025_ED_EDUC_F_5340__3_A_KarenMurray (extra tail is ignored)
  #
  # Captures: year, faculty, subject, term, number, credits, section
  def parse_code(code)
    return {} if code.blank?

    m = code.match(
      /\A
        (?<year>\d{4})_
        (?<faculty>[A-Z]+)_
        (?<subject>[A-Z]+)_
        (?<term>F|W|FW|Y|S|SU|S1|S2)_
        (?<number>[A-Z0-9]+)__
        (?<credits>[0-9]+(?:\.[0-9]{1,2})?)_
        (?<section>[A-Z0-9]+)
      /x
    )
    return {} unless m

    m.named_captures.transform_keys!(&:to_sym)
  end

  def build_label(course, p)
    if p.present?
      credits = p[:credits].to_s.include?('.') ? p[:credits] : "#{p[:credits]}.00"
      instructor = display_instructor(course.instructor)

      # [course title] [faculty]/[subject] [course_number] [credits] [section] [instructor name]
      # Example: "Independent Study, HH/GH 4000 3.00, A, Amrita Daftary"
      "#{course.name}, #{p[:faculty]}/#{p[:subject]} #{p[:number]} #{credits}, #{p[:section]}, #{instructor}"
    else
      instructor = display_instructor(course.instructor)
      "#{course.name}, #{course.code}, #{instructor}"
    end
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
