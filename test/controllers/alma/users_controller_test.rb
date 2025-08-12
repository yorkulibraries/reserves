# frozen_string_literal: true

require 'test_helper'

class Alma::UsersControllerTest < ActionDispatch::IntegrationTest

    setup do
        @user = create(:user, admin: true, role: User::MANAGER_ROLE)
        log_user_in(@user)
      end

    test 'lookup_by_name returns expected user data' do
        # Stub the Alma::User.find_by_name method
        mock_response = [
            {
            'first_name' => 'Jane',
            'last_name' => 'Doe',
            'primary_id' => 'jdoe123',
            'contact_info' => {
                'email' => [{ 'email_address' => 'jane.doe@example.com' }]
            }
            }
        ]

        Alma::User.expects(:find_by_name)
                    .with(first_name: 'Jane', last_name: 'Doe')
                    .returns(mock_response)

        get '/alma/users/lookup_by_name', params: {
            first_name: 'Jane',
            last_name: 'Doe'
        }

        assert_response :success
        body = JSON.parse(response.body)

        expected = [{
            'name' => 'Jane Doe',
            'email' => 'jane.doe@example.com',
            'primary_id' => 'jdoe123'
        }]

        assert_equal expected, body
    end

    test 'lookup_by_name strips special characters from names' do
        # Make sure name sanitation works
        Alma::User.expects(:find_by_name)
                    .with(first_name: 'Jane', last_name: 'Doe')
                    .returns([])

        get '/alma/users/lookup_by_name', params: {
            first_name: 'Jane<>',
            last_name: 'Doe!!'
        }

        assert_response :success
        assert_equal [], JSON.parse(response.body)
    end
end
