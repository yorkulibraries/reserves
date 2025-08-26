namespace :courses do
  desc "Load course info from CSV file. Usage: rails courses:load_courses_csv CSV=/path/to/courses.csv"
  task load_courses_csv: :environment do
    file_path = ENV['CSV']

    unless file_path
      puts "Error: CSV file path not provided. Usage: rails courses:load_courses_csv CSV=/path/to/courses.csv"
      exit
    end

    unless File.exist?(file_path)
      puts "Error: CSV file not found at #{file_path}"
      exit
    end

    puts "Starting CSV import from #{file_path}..."

    CourseInfo.delete_all

    result = CsvCourseInfoLoader.new(file_path).call

    if result.success
      puts "Successfully imported #{result.data.count} courses from #{file_path}"
    else
      puts "Errors occurred:"
      result.errors.each { |error| puts "  - #{error}" }
      exit 1
    end
  end
end