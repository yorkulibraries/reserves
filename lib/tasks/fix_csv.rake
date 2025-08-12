# lib/tasks/fix_csv.rake
require 'csv'

namespace :csv do
  desc "Fix a broken CSV by manually repairing lines with extra commas"
  task :fix, [:input_file, :output_file, :expected_columns] => :environment do |t, args|
    input_path = args[:input_file]
    output_path = args[:output_file]
    expected_columns = args[:expected_columns].to_i

    if input_path.nil? || output_path.nil? || expected_columns.zero?
      puts "⚠️ Usage: rake csv:fix[input.csv,fixed.csv,expected_columns]"
      exit
    end

    puts "📄 Reading #{input_path}..."

    fixed_rows = []
    headers = nil

    File.open(input_path).each_with_index do |line, idx|
      
      line = line.strip.gsub("\r", "")

      
      columns = line.split(",")

      if idx == 0
        headers = columns
        fixed_rows << headers
        next
      end

      
      if columns.length > expected_columns
        fixed = []

        fixed += columns[0..5] 

        
        course_name = columns[6..-3].join(",").strip
        fixed << course_name

        
        fixed += columns[-2..-1]

        fixed_rows << fixed
      else
        fixed_rows << columns
      end
    end

    puts "🛠 Writing fixed CSV to #{output_path}..."
    CSV.open(output_path, "w") do |csv|
      fixed_rows.each { |row| csv << row }
    end

    puts "✅ CSV fix complete! Output saved to #{output_path}"
  end
end
