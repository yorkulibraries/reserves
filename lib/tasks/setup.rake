# frozen_string_literal: true

namespace :app do
  task set_alma_api_key: :environment do
    Setting.primo_apikey = ENV['PRIMO_API_KEY']
    Setting.alma_apikey= ENV['ALMA_API_KEY']
    Setting.worldcat_key= ENV['WORLDCAT_API_KEY']
  end
end
