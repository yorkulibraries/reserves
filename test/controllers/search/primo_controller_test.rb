# frozen_string_literal: true

require 'test_helper'

module Search
  class PrimoControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user, admin: true, role: User::MANAGER_ROLE)
      log_user_in(@user)
    end

    test 'returns bad gateway when Primo service raises error' do
      BibFinder.any_instance.expects(:search_primo).raises(StandardError.new('timeout'))

      post search_primo_path, params: { q: 'economics', type: 'book' }, xhr: true

      assert_response :bad_gateway
      assert_includes response.body, 'primo:search-error'
    end
  end
end
