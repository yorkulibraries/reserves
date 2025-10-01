# frozen_string_literal: true

require 'test_helper'

class AlmaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, admin: true, role: User::MANAGER_ROLE)
    log_user_in(@user)
  end

  test 'returns 422 when MMS ID is blank' do
    post alma_lookup_path, params: { mms_id: '' }

    assert_response :unprocessable_entity
    assert_equal 'Blank MMS ID', JSON.parse(response.body)['error']
  end

  test 'returns 404 when Alma record not found' do
    AlmaService.expects(:fetch_bib).with('123').returns(nil)

    post alma_lookup_path, params: { mms_id: '123' }

    assert_response :not_found
    assert_equal 'Not found', JSON.parse(response.body)['error']
  end

  test 'returns 422 when API key missing' do
    AlmaService.expects(:fetch_bib).with('456')
                .raises(StandardError.new('Missing ALMA_API_KEY please set'))

    post alma_lookup_path, params: { mms_id: '456' }

    assert_response :unprocessable_entity
    assert_equal 'Alma API key not configured', JSON.parse(response.body)['error']
  end

  test 'returns 502 when Alma lookup raises unexpected error' do
    AlmaService.expects(:fetch_bib).with('789')
                .raises(Net::ReadTimeout.new('timeout'))

    post alma_lookup_path, params: { mms_id: '789' }

    assert_response :bad_gateway
    assert_equal 'Lookup failed', JSON.parse(response.body)['error']
  end
end
