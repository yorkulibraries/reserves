# frozen_string_literal: true

require 'test_helper'

module Alma
  class ReadingListTest < ActiveSupport::TestCase
    setup do
      Setting.stubs(:alma_region).returns('https://alma.example.edu')
      Setting.stubs(:alma_apikey).returns('secret')
      Rails.logger.stubs(:error)
      Rails.logger.stubs(:warn)
    end

    teardown do
      Setting.unstub(:alma_region)
      Setting.unstub(:alma_apikey)
      Rails.logger.unstub(:error)
      Rails.logger.unstub(:warn)
    end

    should 'create reading list via Alma API' do
      response_body = { 'id' => 'RL-1' }.to_json
      http_response = Net::HTTPCreated.new('1.1', '201', 'Created')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, response_body)

      http = mock('http')
      Net::HTTP.expects(:new).with('alma.example.edu', 443).returns(http)
      http.expects(:use_ssl=).with(true)

      request = mock('request')
      Net::HTTP::Post.expects(:new).once.returns(request)
      request.stubs(:[]=)
      request.stubs(:body=)

      http.expects(:request).with(request).returns(http_response)

      result = ReadingList.create(course_id: 'COURSE1', name: 'Course', description: 'Desc')
      assert_equal 'RL-1', result['id']
    end

    should 'return nil and log when reading list creation fails' do
      http_response = Net::HTTPForbidden.new('1.1', '403', 'Forbidden')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, 'nope')

      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.stubs(:use_ssl=)

      request = mock('request')
      Net::HTTP::Post.expects(:new).returns(request)
      request.stubs(:[]=)
      request.stubs(:body=)

      http.expects(:request).with(request).returns(http_response)

      Rails.logger.expects(:error).with(regexp_matches(/Reading List creation failed/i))

      assert_nil ReadingList.create(course_id: 'COURSE1', name: 'Course', description: 'Desc')
    end

    should 'add citation and return parsed payload on success' do
      citation_data = { 'metadata' => { 'title' => 'Example' } }
      response_body = { 'id' => 'CIT-1' }.to_json

      http_response = Net::HTTPCreated.new('1.1', '201', 'Created')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, response_body)

      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.expects(:use_ssl=).with(true)

      request = mock('request')
      Net::HTTP::Post.expects(:new).returns(request)
      request.stubs(:[]=)
      request.expects(:body=).with(citation_data.to_json)

      http.expects(:request).with(request).returns(http_response)

      result = ReadingList.add_citation(course_id: 'COURSE1', reading_list_id: 'LIST1', citation_data: citation_data)
      assert_equal 'CIT-1', result['id']
    end

    should 'return nil and log on failed citation creation' do
      citation_data = { 'metadata' => { 'title' => 'Failure' } }

      http_response = Net::HTTPServerError.new('1.1', '500', 'Error')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, 'boom')

      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.stubs(:use_ssl=)

      request = mock('request')
      Net::HTTP::Post.expects(:new).returns(request)
      request.stubs(:[]=)
      request.stubs(:body=)

      http.expects(:request).with(request).returns(http_response)

      Rails.logger.expects(:error).with(regexp_matches(/add_citation failed/i))

      result = ReadingList.add_citation(course_id: 'COURSE1', reading_list_id: 'LIST1', citation_data: citation_data)
      assert_nil result
    end

    should 'fetch items for reading list' do
      response_body = { 'citation' => [{ 'id' => 'C1' }] }.to_json
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, response_body)

      ReadingList.expects(:perform_get_request).returns(response)

      result = ReadingList.get_items_for_reading_list('COURSE1', 'LIST1')
      assert_equal ['C1'], result.map { |c| c['id'] }
    end

    should 'return empty array when reading list fetch fails' do
      response = Net::HTTPServerError.new('1.1', '500', 'Boom')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, 'error')

      ReadingList.expects(:perform_get_request).returns(response)

      assert_equal [], ReadingList.get_items_for_reading_list('COURSE1', 'LIST1')
    end

    should 'return parsed citation when fetching single citation succeeds' do
      response_body = { 'id' => 'C1', 'metadata' => { 'title' => 'Single' } }.to_json
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, response_body)

      ReadingList.expects(:perform_get_request).returns(response)

      result = ReadingList.get_citation('COURSE1', 'LIST1', 'C1')
      assert_equal 'Single', result['metadata']['title']
    end

    should 'log and return nil when fetching single citation fails' do
      response = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, 'missing')

      ReadingList.expects(:perform_get_request).returns(response)
      Rails.logger.expects(:error).with(regexp_matches(/Failed to fetch citation/))

      assert_nil ReadingList.get_citation('COURSE1', 'LIST1', 'C1')
    end

    should 'delete citation successfully when Alma returns 204' do
      http_response = Net::HTTPNoContent.new('1.1', '204', 'No Content')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, '')

      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.stubs(:use_ssl=)

      request = mock('request')
      Net::HTTP::Delete.expects(:new).returns(request)
      request.stubs(:[]=)

      http.expects(:request).with(request).returns(http_response)

      assert ReadingList.delete_citation(course_id: 'COURSE1', reading_list_id: 'LIST1', citation_id: 'C1')
    end

    should 'return false and log when delete_citation fails' do
      http_response = Net::HTTPServerError.new('1.1', '500', 'Error')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, 'bad')

      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.stubs(:use_ssl=)

      request = mock('request')
      Net::HTTP::Delete.expects(:new).returns(request)
      request.stubs(:[]=)

      http.expects(:request).with(request).returns(http_response)

      Rails.logger.expects(:error).with(regexp_matches(/delete_citation failed/i))

      assert_not ReadingList.delete_citation(course_id: 'COURSE1', reading_list_id: 'LIST1', citation_id: 'C1')
    end

    should 'return nil when reading list lookup finds no lists' do
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, { 'reading_list' => [] }.to_json)

      ReadingList.expects(:perform_get_request).returns(response)

      assert_nil ReadingList.get_reading_list_for_course('COURSE1')
    end

    should 'delete reading list through Alma API' do
      http_response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, '')

      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.stubs(:use_ssl=)

      request = mock('request')
      Net::HTTP::Delete.expects(:new).returns(request)
      request.stubs(:[]=)

      http.expects(:request).with(request).returns(http_response)

      assert ReadingList.delete(course_id: 'COURSE1', reading_list_id: 'LIST1')
    end

    should 'return false when reading list deletion fails without raising' do
      http_response = Net::HTTPInternalServerError.new('1.1', '500', 'Error')
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, 'bad')

      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.stubs(:use_ssl=)

      request = mock('request')
      Net::HTTP::Delete.expects(:new).returns(request)
      request.stubs(:[]=)

      http.expects(:request).with(request).returns(http_response)

      assert_not ReadingList.delete(course_id: 'COURSE1', reading_list_id: 'LIST1')
    end

    should 'log and return false when reading list deletion raises error' do
      http = mock('http')
      Net::HTTP.expects(:new).returns(http)
      http.stubs(:use_ssl=)

      request = mock('request')
      Net::HTTP::Delete.expects(:new).returns(request)
      request.stubs(:[]=)

      http.expects(:request).with(request).raises(StandardError.new('boom'))

      Rails.logger.expects(:error).with(regexp_matches(/Alma::ReadingList.delete failed/i))

      assert_not ReadingList.delete(course_id: 'COURSE1', reading_list_id: 'LIST1')
    end
  end
end
