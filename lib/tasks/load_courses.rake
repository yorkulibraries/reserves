require 'json'
require 'date'
require 'csv'

namespace :courses do

  task init: :environment do
    ## LOAD DATA SCRAPED FROM YUL ICAL
    Rake::Task['courses:load_yorku_data'].invoke
  end

  task update: :environment do
    Rake::Task['courses:load_yorku_data'].invoke
  end

  task load_yorku_data: :environment do
    csv_dir       = Rails.root.join('lib', 'assets', 'course-data')
    instructor_csv = Dir.glob(csv_dir.join('course_info.csv')).first

    # 1) Build instructor lookup
    instructor_map = {}
    if instructor_csv && File.exist?(instructor_csv)
      CSV.foreach(instructor_csv, headers: true, quote_char: '"') do |row|
        key = [
          row['FACULTY']&.strip,        # code_faculty
          row['SUBJECT']&.strip,        # code_subject
          row['COURSE_NUMBER']&.strip,  # numeric part
          row['CREDIT']&.strip          # code_credits
        ]
        instructor_map[key] = row['INSTRUCTOR_NAME']&.strip
      end
      puts "Loaded #{instructor_map.size} instructors from #{File.basename(instructor_csv)}"
    else
      puts "⚠️  Instructor CSV not found, will use empty"
    end

    # 2) Preload existing course codes
    existing_codes = Course.pluck(:code).to_set
    new_records    = []
    new_count      = 0

    # 3) Process each data CSV except the instructor one
    Dir.glob(csv_dir.join('*.csv')).sort.each do |data_file|
      next if data_file == instructor_csv

      puts "Processing #{File.basename(data_file)}"
      CSV.foreach(data_file, headers: true, quote_char: '"') do |row|
        # normalize values
        acad_term    = row['STUDYSESSION']&.strip
        acad_year    = row['ACADEMICYEAR']&.strip
        fac_abbrev   = row['FACULTY_ABREV']&.strip
        subj_abbrev  = row['SUBJECT_ABREV']&.strip
        title        = row['COURSETITLE']&.strip
        num          = row['COURSE_NUMBER'].to_s.gsub(/\D/, '').strip
        creds        = row['CREDIT']&.strip
        sect         = row['SECTION']&.strip

        # composite code
        code = [acad_year, fac_abbrev, subj_abbrev, acad_term, num, '', creds, sect].join('_')

        # skip existing
        next if existing_codes.include?(code)

        # find instructor by the four‐field key
        instr_key      = [fac_abbrev, subj_abbrev, num, creds]
        instructor_txt = instructor_map[instr_key] || ''

        # collect for bulk insert
        new_records << {
          code:          code,
          code_year:     acad_year,
          code_faculty:  fac_abbrev,
          code_subject:  subj_abbrev,
          code_term:     acad_term,
          code_credits:  creds,
          code_section:  sect,
          name:          title,
          student_count: 1,
          instructor:    instructor_txt,
          created_at:    Time.current,
          updated_at:    Time.current
        }

        existing_codes.add(code)
        new_count += 1
      end
    end

    # 4) Bulk‐insert
    if new_records.any?
      Course.insert_all(new_records)
      puts "✅ Inserted #{new_count} new courses"
    else
      puts "No new courses to insert"
    end
  end

end
