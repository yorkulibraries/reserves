# frozen_string_literal: false

# some of the comments are in UTF-8
ENV['RAILS_ENV'] = 'test'
require File.expand_path('../config/environment', __dir__)
require 'rails/test_help'
require 'factory_girl_rails'
require 'minitest/unit'
require 'database_cleaner/active_record'

# Configure shoulda-matchers to use Minitest
require 'shoulda/matchers'

DatabaseCleaner.url_allowlist = [
  %r{.*test.*}
]
DatabaseCleaner.strategy = :truncation

include ActionDispatch::TestProcess

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
    #
    # Note: You'll currently still have to declare fixtures explicitly in integration tests
    # -- they do not yet inherit this setting

    # fixtures :all

    # Add more helper methods to be used by all tests here...
    include FactoryGirl::Syntax::Methods
    include Warden::Test::Helpers
    include ActionMailer::TestHelper
    include ActiveJob::TestHelper

    Warden.test_mode!

    setup do
      DatabaseCleaner.start
    end

    teardown do
      DatabaseCleaner.clean
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionDispatch::TestProcess
  include ActionMailer::TestHelper

  include Warden::Test::Helpers
  Warden.test_mode!

  def log_user_in(user)
    get login_url, headers: { 
      'HTTP_PYORK_USER' => user.username, 'HTTP_PYORK_EMAIL' => user.email, 
      'HTTP_PYORK_CYIN' => user.univ_id, 'HTTP_PYORK_TYPE' => user.user_type
    }
  end

  def get_instance_var(what)
    controller.instance_variable_get("@#{what}")
  rescue NameError => e
    nil
  end

  def assert_template(which); end
end
