namespace :admin do
  desc "Reindex all models"
  task reindex_all: :environment do
      User.reindex
      Request.reindex
      Item.reindex
      Course.reindex
      CourseInfo.reindex
      Location.reindex
  end

  task reindex_courses: :environment do
      Course.reindex
      CourseInfo.reindex
  end

  desc "List invalid users"
  task invalid_user_records: :environment do
    User.all.each do |u|
      if !u.valid?
        puts "#{u.id},#{u.username},#{u.univ_id},#{u.email},#{u.role}"
      end
    end
  end
end
