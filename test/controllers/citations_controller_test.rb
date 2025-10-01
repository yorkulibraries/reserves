# frozen_string_literal: true

require 'test_helper'

class CitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, admin: true, role: User::MANAGER_ROLE)
    log_user_in(@user)
    Rails.logger.stubs(:error)
  end

  teardown do
    Rails.logger.unstub(:error)
  end

  should 'return parsed citation data' do
    AnyStyleService.expects(:parse).with('Doe 2020').returns(
      'title' => 'Sample Title',
      'author' => [{ 'given' => 'Jane', 'family' => 'Doe' }],
      'year' => '2020'
    )

    post '/citations/parse', params: { citation: 'Doe 2020' }

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal 'Sample Title', body['title']
    assert_equal 'Jane Doe', body['author']
    assert_equal '2020', body['publication_date']
    assert_equal 'Doe 2020', body['raw_citation']
  end

  should 'reject blank citation submissions' do
    post '/citations/parse', params: { citation: ' ' }

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_equal 'Blank citation', body['error']
  end

  should 'handle parser exceptions gracefully' do
    AnyStyleService.expects(:parse).raises(StandardError.new('boom'))
    Rails.logger.expects(:error).with(regexp_matches(/boom/))

    post '/citations/parse', params: { citation: 'Doe 2020' }

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_equal 'Could not parse citation', body['error']
  end
end
