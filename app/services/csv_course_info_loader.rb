# app/services/csv_course_info_loader.rb
require 'csv'

class CsvCourseInfoLoader
  Result = Struct.new(:success, :data, :errors, keyword_init: true)

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    unless File.exist?(@file_path)
      return Result.new(success: false, errors: ["File not found at #{@file_path}"])
    end

    unless File.extname(@file_path) == '.csv'
      return Result.new(success: false, errors: ["File must be a .csv file"])
    end

    courses = []
    errors = []

    CSV.foreach(@file_path, headers: true, header_converters: :symbol) do |row|
      # Convert empty strings and whitespace-only strings to nil
      cleaned_row = row.to_h.transform_values { |value| value&.strip&.empty? ? nil : value&.strip }

      course_attributes = {
        faculty: cleaned_row[:faculty],
        faculty_abrev: cleaned_row[:faculty_abrev],
        faculty_short: cleaned_row[:faculty_short],
        period_faculty: cleaned_row[:periodfaculty],
        subject_abrev: cleaned_row[:subject_abrev],
        subject_abrev2: cleaned_row[:subject_abrev2],
        subject: cleaned_row[:subject].presence || cleaned_row[:subject_abrev],
        academic_year: cleaned_row[:academicyear],
        study_session: cleaned_row[:studysession],
        crs_id: cleaned_row[:crsid],
        course_title: cleaned_row[:coursetitle],
        course_title1: cleaned_row[:coursetitle1],
        course_number: cleaned_row[:course_number],
        year_level: cleaned_row[:year_level],
        credit: cleaned_row[:credit],
        section: cleaned_row[:section],
        instructor_name: cleaned_row[:instructor_name]
      }

      course = CourseInfo.new(course_attributes)
      if course.save
        courses << course
      else
        errors << "Failed to save course: #{course_attributes[:course_title] || 'Unknown'} - #{course.errors.full_messages.join(', ')}"
      end
    end

    if errors.empty?
      Result.new(success: true, data: courses, errors: [])
    else
      Result.new(success: false, data: courses, errors: errors)
    end
  end
end