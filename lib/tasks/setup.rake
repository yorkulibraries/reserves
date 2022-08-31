# frozen_string_literal: true

namespace :app do
  config = Rails.application.config_for(:api_keys)
  task set_alma_api_key: :environment do
    Setting.primo_apikey = config['primo_api_key']
    Setting.primo_inst = config['primo_inst']
    Setting.primo_vid = config['primo_vid']
    Setting.primo_region = config['primo_region']
    Setting.primo_scope = config['primo_scope']

    Setting.alma_apikey= config['alma_api_key']
    Setting.worldcat_key= config['worldcat_api_key']
  end
end
