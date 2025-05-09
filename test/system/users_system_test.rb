require 'application_system_test_case'
require 'helpers/system_test_helper'
require 'devise/test/integration_helpers' # Add this line

class UserSystemTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers # Include the Devise helpers
  include SystemTestHelper  # Include the SystemTestHelper module here

  setup do
    @admin_user = create(:user, admin: true, role: User::MANAGER_ROLE)
    @user = FactoryGirl.create(:user, role: User::INSTRUCTOR_ROLE)
    @reserves_staff = create_list(:user, 3, admin:true, is_reserves_staff: true, role: User::MANAGER_ROLE)
    @non_reserves_staff = create_list(:user, 4, admin:true, is_reserves_staff: false, role: User::MANAGER_ROLE)
  end

  should "Admin View: is_reserves_staff visible" do 
    login_as(@admin_user)
    visit admin_users_users_url

    assert_text "Is Reserves Staff"#, "Is Reserve Staff not visible on admin user list" 
        
    visit edit_user_url(@non_reserves_staff.first)
    assert_selector "input[name='user[is_reserves_staff]']"
    check "user_is_reserves_staff", visible: :all
    
    assert_difference 'User.where(is_reserves_staff: true).count', 1 do
      click_button('Save User Details')
    end
  end

end

########################################
## For Debugging and building tests ##
# page.driver.browser.manage.window.resize_to(1920, 2500)
# save_screenshot()
## HTML Save
# File.open("tmp/test-screenshots/error.html", "w") { |file| file.write(page.html) }
# save_page()
########################################