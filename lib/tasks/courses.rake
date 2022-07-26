namespace :courses do
  desc "Courses Tasks"

  #######################################################
  ############### SEND EXPIRY NOTICES ###################
  #######################################################

  task update_course_code_fields: :environment do
    report "Updating course code fields"

    Course.all.each do |c|
      c.save
      puts c.inspect
    end
  end



  #######################################################
  ############### LOG PROGRESS FOR LATER ################
  #######################################################

  def report(string)
    @report_log = Array.new if @report_log == nil

    @report_log << "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} --- #{string}"

    if ENV['REPORT'] != nil
      puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} --- #{string}"
    end
  end
end
