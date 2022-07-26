ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
include ActionDispatch::TestProcess


class ActiveSupport::TestCase

  # Add more helper methods to be used by all tests here...
  # include ActionDispatch::TestProcess
  include FactoryGirl::Syntax::Methods
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper
end

class ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def log_user_in(user)
    get login_url, headers: { "HTTP_PYORK_USER" => user.uid }
  end

  def get_instance_var(what)
    controller.instance_variable_get("@#{what.to_s}")
  rescue NameError => e
    return nil
  end

  def assert_template(which)

  end

end
