namespace :searchkick do
  desc "Reindex all models"
  task reindex_all: :environment do
      User.reindex
      Request.reindex
      Item.reindex
      Course.reindex
      Location.reindex
  end
end
