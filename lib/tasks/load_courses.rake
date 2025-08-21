require 'json'
require 'date'
require 'csv'
require 'set'

namespace :courses do
  task init: :environment do
    Rake::Task['courses:load_yorku_data'].invoke
  end

  task update: :environment do
    Rake::Task['courses:load_yorku_data'].invoke
  end

  task load_yorku_data: :environment do
    csv_dir = Rails.root.join('lib', 'assets', 'course-data')

    existing_codes = Course.pluck(:code).to_set
    new_records    = []
    new_count      = 0

    Dir.glob(csv_dir.join('*.csv')).sort.each do |data_file|
      puts "Processing #{File.basename(data_file)}"

      CSV.foreach(data_file, headers: true, encoding: 'bom|utf-8') do |row|
        h = row.to_h.transform_keys { |k|
          k.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
            .gsub("\uFEFF", '').strip.upcase
        }.transform_values { |v| v.is_a?(String) ? v.strip : v }

        acad_term        = h['STUDYSESSION']
        acad_year        = h['ACADEMICYEAR']
        fac_abbrev       = h['FACULTY_ABREV'] || h['FACULTY_SHORT'] || h['FACULTY']
        subj_abbrev      = h['SUBJECT_ABREV'] || h['SUBJECT_ABREV2'] || h['SUBJECT']
        title            = h['COURSETITLE']   || h['COURSETITLE1']

        course_number_csv = h['COURSE_NUMBER']

        num_for_code     = course_number_csv.to_s.gsub(/\D/, '').strip

        creds            = h['CREDIT']
        sect             = h['SECTION']

        instructor_txt   = (h['INSTRUCTOR_NAME'] || h['INSTRUCTOR'] || h['PRIMARY_INSTRUCTOR'] || '').to_s.strip
        instructor_token = instructor_txt.gsub(/[^\p{Alnum}]+/, '') # e.g., "Karen Murray" -> "KarenMurray"

        base_code = [acad_year, fac_abbrev, subj_abbrev, acad_term, num_for_code, '', creds, sect].join('_')
        code      = instructor_token.empty? ? base_code : "#{base_code}_#{instructor_token}"

        next if existing_codes.include?(code)

        new_records << {
          code:           code,
          code_year:      acad_year,
          code_faculty:   fac_abbrev,
          code_subject:   subj_abbrev,
          code_term:      acad_term,
          code_credits:   creds,
          code_section:   sect,
          name:           title,
          student_count:  1,
          instructor:     instructor_txt,
          course_number:  course_number_csv,
          created_at:     Time.current,
          updated_at:     Time.current
        }

        existing_codes.add(code)
        new_count += 1
      end
    end

    if new_records.any?
      Course.insert_all(new_records)
      puts "✅ Inserted #{new_count} new courses (code includes instructor; course_number set from CSV)"
    else
      puts "No new courses to insert"
    end
  end
end