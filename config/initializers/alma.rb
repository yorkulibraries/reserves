
require 'alma'
require Rails.root.join('lib', 'alma', 'course.rb')
require Rails.root.join('lib', 'alma', 'user.rb')
require Rails.root.join('app', 'models', 'setting.rb')
Alma.configure do |config|
    config.apikey = Setting.alma_apikey
    config.region = Setting.alma_region

    config.enable_loggable = false
    config.timeout = 10
  end 
