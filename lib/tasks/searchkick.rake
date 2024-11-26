namespace :searchkick do
  desc "Reindex all models"
  task reindex_all: :environment do
    [User, Request, Item, Course, Location].each do |model|
      puts "Reindexing #{model.name}..."
      model.reindex
    end
  end
end
