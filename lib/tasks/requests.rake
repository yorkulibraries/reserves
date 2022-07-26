namespace :requests do
  desc "Requests Task"

  #######################################################
  ############### SEND EXPIRY NOTICES ###################
  #######################################################

  task send_expiry_notices: :environment do
    report "Sending Expiring notices"
    requests = Request.expiring_soon

    if ENV["EXPIRE_DATE"]
      requests = Request.expiring_soon(ENV["EXPIRE_DATE"])
    end

    report "Found Requests: #{requests.size}"

    requests_notified =  []

    requests.each do |request|

      if ENV["SENDER"]
        sender = User.find(ENV["SENDER"])
      else
        sender = User.new(name: "Reserves System", email: Setting.email_from)
      end



      RequestMailer.expiry_notice(request, sender).deliver_now unless ENV["DRY_RUN"] == "true"

      requests_notified << request.id
    end

    #report "Requests: #{requests_notified.join(",")}"
    report "----------"
    report "DRY RUN" if ENV["DRY_RUN"] == "true"
    report "Sent #{requests_notified.size} notices"
    report "----------"
    report "IDs: #{requests_notified.join(", ")}"



    if ENV["EMAIL_REPORT_TO"]
      ReportMailer.mail_report(ENV["EMAIL_REPORT_TO"], 'Expiry Notices Report', @report_log.join("\n")).deliver_now
    end
  end

  #######################################################
  ############### AUTO ARCHIVE REQUESTS #################
  #######################################################

  task auto_archive: :environment do
    user = User.admin.find(Setting.request_archive_all_user_id)

    if user == nil
      user = User.new(email: "lcswatch@gmail.com", id: 1)
    end

    report "DRY RUN" if ENV["DRY_RUN"] == "true"

    if Setting.request_archive_all_allow == "true"

      archive = ENV["DRY_RUN"] == "true" ? false : true

      requests = Request.mass_archive(user.id, archive)

      if requests.size > 0
        report "The following requests have been removed automatically"
        report "----------"
        report "IDs: #{requests.collect { |r| r.id }.join(",")}"
        report "----------"
        report "Total: #{requests.size} request(s)"

      else
        report "Found 0 requests to auto-archive"
        report "----------"
      end

      ReportMailer.mail_report(user.email, "Auto Archive Report", @report_log.join("\n")).deliver_now
    else
      report "Auto Archive is not enabled"
    end

    if ENV["EMAIL_REPORT_TO"]
      ReportMailer.mail_report(ENV["EMAIL_REPORT_TO"], 'Auto Archive Report', @report_log.join("\n")).deliver_now
    end

  end

  #######################################################
  ############### AUTO REMOVE INCOMPLETE REQUESTS #################
  #######################################################

  task remove_incomplete: :environment do

    report "DRY RUN" if ENV["DRY_RUN"] == "true"

    if Setting.request_remove_incomplete_allow.to_s == "true"

      remove = ENV["DRY_RUN"] == "true" ? false : true

      requests = Request.remove_incomplete(remove)

      if requests.size > 0
        report "The following INCOMPLETE requests have been removed permanently"
        report "----------"
        report "IDs: #{requests.collect { |r| r.id }.join(",")}"
        report "----------"
        report "Total: #{requests.size} request(s)"

      else
        report "Found 0 INCOMPLETE requests to auto-remove"
        report "----------"
      end

      if ENV["EMAIL_REPORT_TO"]
        ReportMailer.mail_report(ENV["EMAIL_REPORT_TO"], 'Auto REMOVE INCOMPLETE Report', @report_log.join("\n")).deliver_now
      end

    else
      report "Auto REMOVE INCOMPLETE is not enabled"
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
