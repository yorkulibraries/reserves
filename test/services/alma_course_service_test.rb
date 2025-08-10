require 'test_helper'

class AlmaCourseServiceTest < ActiveSupport::TestCase
  setup do
    # Set default configuration values
    Setting.alma_apikey = 'test-api-key'
    Setting.alma_region = 'https://api-ca.hosted.exlibrisgroup.com'

    # Initialize course, reading list, and citation data
    @course_data = {
      code: 'FF_TEST_F__1001__9_A',
      name: 'Test course API',
      section: 'A',
      processing_department: { value: 'YOR_CR' },
      term: [{ value: 'SUMMER' }],
      status: 'ACTIVE',
      start_date: '2025-09-01Z',
      end_date: '2025-12-31Z',
      year: '2025',
      instructor: [{ primary_id: 'NO_ID' }]
    }
    @reading_list_data = {
      code: 'RL-001',
      name: 'Test Reading List',
      status: 'ACTIVE'
    }
    @citation_data = {
      status: { value: 'BeingPrepared' },
      type: { value: 'BK' },
      secondary_type: { value: 'BK' },
      metadata: {
        title: 'The Art of Happiness',
        author: 'Dalai Lama',
        publisher: 'Riverhead Books',
        publication_date: '1998',
        isbn: '9781573221115',
        mms_id: '991022101949705164'
      }
    }

    # Initialize service and verify
    begin
      @service = AlmaCourseService.new
    rescue RuntimeError => e
      flunk "Failed to initialize AlmaCourseService: #{e.message}"
    end
  end

  teardown do
    # Reset settings to avoid state leakage
    Setting.alma_apikey = nil
    Setting.alma_region = nil
  end

  # Initialization tests
  test 'initializes with valid API key and region' do
    assert_equal 'test-api-key', @service.instance_variable_get(:@api_key), 'Expected API key to match'
    assert_equal 'https://api-ca.hosted.exlibrisgroup.com/almaws/v1', AlmaCourseService.base_uri, 'Expected base URI to match'
  end

  test 'raises error when API key is empty' do
    Setting.alma_apikey = ''
    assert_raises RuntimeError, 'Setting.alma_apikey not set' do
      AlmaCourseService.new
    end
  end

  test 'raises error when region is empty' do
    Setting.alma_apikey = 'test-api-key'
    Setting.alma_region = ''
    assert_raises RuntimeError, 'Setting.alma_region not set' do
      AlmaCourseService.new
    end
  end

  # get_course tests
  test 'get_course returns success response' do
    course_id = '12345'
    success_response = {
      body: {
        id: course_id,
        code: 'FF_TEST_F__1001__9_A',
        name: 'Test course API'
      }.to_json,
      code: 200
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_course(course_id)

    assert result[:success], 'Expected success to be true'
    assert_equal course_id, result[:data][:id], 'Expected course ID to match'
    assert_equal 'FF_TEST_F__1001__9_A', result[:data][:code], 'Expected course code to match'
    assert_equal 'Test course API', result[:data][:name], 'Expected course name to match'
  end

  test 'get_course handles API error' do
    course_id = '12345'
    error_response = {
      body: { error: 'Course not found' }.to_json,
      code: 404,
      message: 'Not Found'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_course(course_id)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 404, result[:error], 'Expected error code to be 404'
    assert_equal 'Not Found', result[:message], 'Expected error message to match'
    assert_equal 'Course not found', result[:details][:error], 'Expected error details to match'
  end

  test 'get_course handles invalid JSON in successful response' do
    course_id = '12345'
    success_response = {
      body: 'invalid json',
      code: 200
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_course(course_id)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 200, result[:error], 'Expected error code to be 200'
    assert_equal 'Invalid JSON in successful response', result[:message], 'Expected error message to match'
    assert_equal 'Invalid JSON response', result[:details][:error], 'Expected error details to match'
  end

  # search_course tests
  test 'search_course with valid query returns success response' do
    query = 'test course'
    success_response = {
      body: {
        courses: [
          { id: '12345', code: 'FF_TEST_F__1001__9_A', name: 'Test course API' }
        ]
      }.to_json,
      code: 200
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:get).with(
      "/courses",
      query: { apikey: 'test-api-key', q: query },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.search_course(query)

    assert result[:success], 'Expected success to be true'
    assert_equal 1, result[:data][:courses].length, 'Expected one course in response'
    assert_equal '12345', result[:data][:courses][0][:id], 'Expected course ID to match'
    assert_equal 'FF_TEST_F__1001__9_A', result[:data][:courses][0][:code], 'Expected course code to match'
  end

  test 'search_course handles API error' do
    query = 'invalid query'
    error_response = {
      body: { error: 'Invalid search query' }.to_json,
      code: 400,
      message: 'Bad Request'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:get).with(
      "/courses",
      query: { apikey: 'test-api-key', q: query },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.search_course(query)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 400, result[:error], 'Expected error code to be 400'
    assert_equal 'Bad Request', result[:message], 'Expected error message to match'
    assert_equal 'Invalid search query', result[:details][:error], 'Expected error details to match'
  end

  # create_course tests
  test 'create_course with specific course_data returns success response' do
    success_response = {
      body: {
        id: '12345',
        code: 'FF_TEST_F__1001__9_A',
        name: 'Test course API',
        status: 'ACTIVE'
      }.to_json,
      code: 201
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:post).with(
      "/courses?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @course_data.to_json
    ).returns(stubbed_response)

    result = @service.create_course(@course_data)

    assert result[:success], 'Expected success to be true'
    assert_equal '12345', result[:data][:id], 'Expected course ID to match'
    assert_equal 'FF_TEST_F__1001__9_A', result[:data][:code], 'Expected course code to match'
    assert_equal 'Test course API', result[:data][:name], 'Expected course name to match'
  end

  test 'create_course with specific course_data handles API error' do
    error_response = {
      body: { error: 'Invalid course code' }.to_json,
      code: 400,
      message: 'Bad Request'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:post).with(
      "/courses?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @course_data.to_json
    ).returns(stubbed_response)

    result = @service.create_course(@course_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 400, result[:error], 'Expected error code to be 400'
    assert_equal 'Bad Request', result[:message], 'Expected error message to match'
    assert_equal 'Invalid course code', result[:details][:error], 'Expected error details to match'
  end

  test 'create_course handles invalid JSON response' do
    error_response = {
      body: 'invalid json',
      code: 500,
      message: 'Internal Server Error'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:post).with(
      "/courses?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @course_data.to_json
    ).returns(stubbed_response)

    result = @service.create_course(@course_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 500, result[:error], 'Expected error code to be 500'
    assert_equal 'Internal Server Error', result[:message], 'Expected error message to match'
    assert_equal 'Invalid JSON response', result[:details][:error], 'Expected error details to match'
  end

  test 'create_course handles empty response body on success' do
    success_response = {
      body: '',
      code: 201
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:post).with(
      "/courses?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @course_data.to_json
    ).returns(stubbed_response)

    result = @service.create_course(@course_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 201, result[:error], 'Expected error code to be 201'
    assert_equal 'Invalid JSON in successful response', result[:message], 'Expected error message to match'
    assert_equal 'Invalid JSON response', result[:details][:error], 'Expected error details to match'
  end

  test 'create_course with missing required course data' do
    invalid_course_data = @course_data.except(:code) # Remove required 'code' field

    error_response = {
      body: { error: 'Missing required field: code' }.to_json,
      code: 400,
      message: 'Bad Request'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:post).with(
      "/courses?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: invalid_course_data.to_json
    ).returns(stubbed_response)

    result = @service.create_course(invalid_course_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 400, result[:error], 'Expected error code to be 400'
    assert_equal 'Bad Request', result[:message], 'Expected error message to match'
    assert_equal 'Missing required field: code', result[:details][:error], 'Expected error details to match'
  end

  # update_course tests
  test 'update_course with specific course_data returns success response' do
    course_id = '12345'
    success_response = {
      body: {
        id: course_id,
        code: 'FF_TEST_F__1001__9_A',
        name: 'Test course API',
        status: 'ACTIVE'
      }.to_json,
      code: 200
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:put).with(
      "/courses/#{course_id}?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @course_data.to_json
    ).returns(stubbed_response)

    result = @service.update_course(course_id, @course_data)

    assert result[:success], 'Expected success to be true'
    assert_equal course_id, result[:data][:id], 'Expected course ID to match'
    assert_equal 'FF_TEST_F__1001__9_A', result[:data][:code], 'Expected course code to match'
    assert_equal 'Test course API', result[:data][:name], 'Expected course name to match'
  end

  test 'update_course handles API error' do
    course_id = '12345'
    error_response = {
      body: { error: 'Course not found' }.to_json,
      code: 404,
      message: 'Not Found'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:put).with(
      "/courses/#{course_id}?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @course_data.to_json
    ).returns(stubbed_response)

    result = @service.update_course(course_id, @course_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 404, result[:error], 'Expected error code to be 404'
    assert_equal 'Not Found', result[:message], 'Expected error message to match'
    assert_equal 'Course not found', result[:details][:error], 'Expected error details to match'
  end

  # get_reading_lists tests
  test 'get_reading_lists returns success response' do
    course_id = '12345'
    success_response = {
      body: {
        reading_lists: [
          { id: 'RL-001', code: 'RL-001', name: 'Test Reading List', status: 'ACTIVE' }
        ]
      }.to_json,
      code: 200
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}/reading-lists",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_reading_lists(course_id)

    assert result[:success], 'Expected success to be true'
    assert_equal 1, result[:data][:reading_lists].length, 'Expected one reading list in response'
    assert_equal 'RL-001', result[:data][:reading_lists][0][:id], 'Expected reading list ID to match'
    assert_equal 'Test Reading List', result[:data][:reading_lists][0][:name], 'Expected reading list name to match'
  end

  test 'get_reading_lists handles API error' do
    course_id = '12345'
    error_response = {
      body: { error: 'Course not found' }.to_json,
      code: 404,
      message: 'Not Found'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}/reading-lists",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_reading_lists(course_id)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 404, result[:error], 'Expected error code to be 404'
    assert_equal 'Not Found', result[:message], 'Expected error message to match'
    assert_equal 'Course not found', result[:details][:error], 'Expected error details to match'
  end

  # create_reading_list tests
  test 'create_reading_list returns success response' do
    course_id = '12345'
    success_response = {
      body: {
        id: 'RL-001',
        code: 'RL-001',
        name: 'Test Reading List',
        status: 'ACTIVE'
      }.to_json,
      code: 201
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:post).with(
      "/courses/#{course_id}/reading-lists?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @reading_list_data.to_json
    ).returns(stubbed_response)

    result = @service.create_reading_list(course_id, @reading_list_data)

    assert result[:success], 'Expected success to be true'
    assert_equal 'RL-001', result[:data][:id], 'Expected reading list ID to match'
    assert_equal 'Test Reading List', result[:data][:name], 'Expected reading list name to match'
  end

  test 'create_reading_list handles API error' do
    course_id = '12345'
    error_response = {
      body: { error: 'Invalid reading list data' }.to_json,
      code: 400,
      message: 'Bad Request'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:post).with(
      "/courses/#{course_id}/reading-lists?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @reading_list_data.to_json
    ).returns(stubbed_response)

    result = @service.create_reading_list(course_id, @reading_list_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 400, result[:error], 'Expected error code to be 400'
    assert_equal 'Bad Request', result[:message], 'Expected error message to match'
    assert_equal 'Invalid reading list data', result[:details][:error], 'Expected error details to match'
  end

  # update_reading_list tests
  test 'update_reading_list with specific reading_list_data returns success response' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    success_response = {
      body: {
        id: reading_list_id,
        code: 'RL-001',
        name: 'Updated Test Reading List',
        status: 'ACTIVE'
      }.to_json,
      code: 200
    }

    updated_reading_list_data = @reading_list_data.merge(name: 'Updated Test Reading List')

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:put).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: updated_reading_list_data.to_json
    ).returns(stubbed_response)

    result = @service.update_reading_list(course_id, reading_list_id, updated_reading_list_data)

    assert result[:success], 'Expected success to be true'
    assert_equal reading_list_id, result[:data][:id], 'Expected reading list ID to match'
    assert_equal 'Updated Test Reading List', result[:data][:name], 'Expected updated reading list name to match'
  end

  test 'update_reading_list handles API error' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    error_response = {
      body: { error: 'Reading list not found' }.to_json,
      code: 404,
      message: 'Not Found'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:put).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @reading_list_data.to_json
    ).returns(stubbed_response)

    result = @service.update_reading_list(course_id, reading_list_id, @reading_list_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 404, result[:error], 'Expected error code to be 404'
    assert_equal 'Not Found', result[:message], 'Expected error message to match'
    assert_equal 'Reading list not found', result[:details][:error], 'Expected error details to match'
  end

  # get_citations tests
  test 'get_citations returns success response' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    success_response = {
      body: {
        citations: [
          { id: 'CIT-001', type: { value: 'BK' }, metadata: { title: 'The Art of Happiness', author: 'Dalai Lama' } }
        ]
      }.to_json,
      code: 200
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_citations(course_id, reading_list_id)

    assert result[:success], 'Expected success to be true'
    assert_equal 1, result[:data][:citations].length, 'Expected one citation in response'
    assert_equal 'CIT-001', result[:data][:citations][0][:id], 'Expected citation ID to match'
    assert_equal 'The Art of Happiness', result[:data][:citations][0][:metadata][:title], 'Expected citation title to match'
  end

  test 'get_citations handles API error' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    error_response = {
      body: { error: 'Reading list not found' }.to_json,
      code: 404,
      message: 'Not Found'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_citations(course_id, reading_list_id)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 404, result[:error], 'Expected error code to be 404'
    assert_equal 'Not Found', result[:message], 'Expected error message to match'
    assert_equal 'Reading list not found', result[:details][:error], 'Expected error details to match'
  end

  # get_citation tests
  test 'get_citation returns success response' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    citation_id = 'CIT-001'
    success_response = {
      body: {
        id: citation_id,
        type: { value: 'BK' },
        metadata: { title: 'The Art of Happiness', author: 'Dalai Lama' }
      }.to_json,
      code: 200
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_citation(course_id, reading_list_id, citation_id)

    assert result[:success], 'Expected success to be true'
    assert_equal citation_id, result[:data][:id], 'Expected citation ID to match'
    assert_equal 'The Art of Happiness', result[:data][:metadata][:title], 'Expected citation title to match'
  end

  test 'get_citation handles API error' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    citation_id = 'CIT-001'
    error_response = {
      body: { error: 'Citation not found' }.to_json,
      code: 404,
      message: 'Not Found'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:get).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}",
      query: { apikey: 'test-api-key' },
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    ).returns(stubbed_response)

    result = @service.get_citation(course_id, reading_list_id, citation_id)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 404, result[:error], 'Expected error code to be 404'
    assert_equal 'Not Found', result[:message], 'Expected error message to match'
    assert_equal 'Citation not found', result[:details][:error], 'Expected error details to match'
  end

  # create_citation tests
  test 'create_citation returns success response' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    success_response = {
      body: {
        id: 'CIT-001',
        type: { value: 'BK' },
        metadata: { title: 'The Art of Happiness', author: 'Dalai Lama' }
      }.to_json,
      code: 201
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:post).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @citation_data.to_json
    ).returns(stubbed_response)

    result = @service.create_citation(course_id, reading_list_id, @citation_data)

    assert result[:success], 'Expected success to be true'
    assert_equal 'CIT-001', result[:data][:id], 'Expected citation ID to match'
    assert_equal 'The Art of Happiness', result[:data][:metadata][:title], 'Expected citation title to match'
  end

  test 'create_citation handles API error' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    error_response = {
      body: { error: 'Invalid citation data' }.to_json,
      code: 400,
      message: 'Bad Request'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:post).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @citation_data.to_json
    ).returns(stubbed_response)

    result = @service.create_citation(course_id, reading_list_id, @citation_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 400, result[:error], 'Expected error code to be 400'
    assert_equal 'Bad Request', result[:message], 'Expected error message to match'
    assert_equal 'Invalid citation data', result[:details][:error], 'Expected error details to match'
  end

  # update_citation tests
  test 'update_citation returns success response' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    citation_id = 'CIT-001'
    success_response = {
      body: {
        id: citation_id,
        type: { value: 'BK' },
        metadata: { title: 'Updated Art of Happiness', author: 'Dalai Lama' }
      }.to_json,
      code: 200
    }

    updated_citation_data = @citation_data.merge(metadata: @citation_data[:metadata].merge(title: 'Updated Art of Happiness'))

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:put).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: updated_citation_data.to_json
    ).returns(stubbed_response)

    result = @service.update_citation(course_id, reading_list_id, citation_id, updated_citation_data)

    assert result[:success], 'Expected success to be true'
    assert_equal citation_id, result[:data][:id], 'Expected citation ID to match'
    assert_equal 'Updated Art of Happiness', result[:data][:metadata][:title], 'Expected updated citation title to match'
  end

  test 'update_citation handles API error' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    citation_id = 'CIT-001'
    error_response = {
      body: { error: 'Citation not found' }.to_json,
      code: 404,
      message: 'Not Found'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:put).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: @citation_data.to_json
    ).returns(stubbed_response)

    result = @service.update_citation(course_id, reading_list_id, citation_id, @citation_data)

    assert_not result[:success], 'Expected success to be false'
    assert_equal 404, result[:error], 'Expected error code to be 404'
    assert_equal 'Not Found', result[:message], 'Expected error message to match'
    assert_equal 'Citation not found', result[:details][:error], 'Expected error details to match'
  end

  # new_citation tests
  test 'new_citation returns a properly structured citation' do
    citation = @service.new_citation
    assert_equal 'BeingPrepared', citation[:status][:value], 'Expected status to be BeingPrepared'
    assert_equal 'NOTDETERMINED', citation[:copyrights_status][:value], 'Expected copyrights status to be NOTDETERMINED'
    assert_equal 'BK', citation[:type][:value], 'Expected type to be BK'
    assert_equal 'BK', citation[:secondary_type][:value], 'Expected secondary type to be BK'
    assert citation[:metadata].is_a?(Hash), 'Expected metadata to be a hash'
    assert_equal '', citation[:metadata][:title], 'Expected metadata title to be empty'
    assert_equal '', citation[:metadata][:author], 'Expected metadata author to be empty'
  end

  # extract_mms_id tests
  test 'extract_mms_id extracts 18-digit ID from valid URL' do
    url = 'https://ocul-yor.primo.exlibrisgroup.com/permalink/01OCUL_YOR/26r5oc/alma991022101949705164'
    result = @service.extract_mms_id(url)
    assert_equal '991022101949705164', result, 'Expected MMS ID to match'
  end

  test 'extract_mms_id returns nil for invalid URL' do
    url = 'https://example.com/noalma'
    result = @service.extract_mms_id(url)
    assert_nil result, 'Expected MMS ID to be nil for invalid URL'
  end

  # citations_from_string tests
  test 'citations_from_string parses valid citation string' do
    citation_string = "Dalai Lama. (1998). The Art of Happiness. Riverhead Books."
    parsed_metadata = [
      {
        author: [{ family: 'Dalai Lama' }],
        title: ['The Art of Happiness'],
        date: ['1998'],
        publisher: ['Riverhead Books']
      }
    ]

    AnyStyle.stubs(:parse).with(citation_string).returns(parsed_metadata)

    citations = @service.citations_from_string(citation_string)

    assert_equal 1, citations.length, 'Expected one citation'
    assert_equal 'The Art of Happiness', citations[0][:metadata][:title], 'Expected title to match'
    assert_equal 'Dalai Lama', citations[0][:metadata][:author], 'Expected author to match'
    assert_equal 'Riverhead Books', citations[0][:metadata][:publisher], 'Expected publisher to match'
    assert_equal '1998', citations[0][:metadata][:publication_date], 'Expected publication date to match'
    assert_equal '', citations[0][:metadata][:edition], 'Expected edition to be empty'
  end

  test 'citations_from_string handles multiple authors' do
    citation_string = "Dalai Lama and Cutler, H. (1998). The Art of Happiness. Riverhead Books."
    parsed_metadata = [
      {
        author: [
          { family: 'Dalai Lama' },
          { family: 'Cutler', given: 'H' }
        ],
        title: ['The Art of Happiness'],
        date: ['1998'],
        publisher: ['Riverhead Books']
      }
    ]

    AnyStyle.stubs(:parse).with(citation_string).returns(parsed_metadata)

    citations = @service.citations_from_string(citation_string)

    assert_equal 1, citations.length, 'Expected one citation'
    assert_equal 'The Art of Happiness', citations[0][:metadata][:title], 'Expected title to match'
    assert_equal 'Dalai Lama', citations[0][:metadata][:author], 'Expected primary author to match'
    assert_equal 'Cutler, H', citations[0][:metadata][:additional_person_name], 'Expected additional author to match'
    assert_equal 'Riverhead Books', citations[0][:metadata][:publisher], 'Expected publisher to match'
    assert_equal '1998', citations[0][:metadata][:publication_date], 'Expected publication date to match'
    assert_equal '', citations[0][:metadata][:edition], 'Expected edition to be empty'
  end

  test 'citations_from_string handles nil fields' do
    citation_string = "Dalai Lama. (1998). The Art of Happiness."
    parsed_metadata = [
      {
        author: [{ family: 'Dalai Lama' }],
        title: ['The Art of Happiness'],
        date: ['1998']
        # Note: publisher and edition are not provided
      }
    ]

    AnyStyle.stubs(:parse).with(citation_string).returns(parsed_metadata)

    citations = @service.citations_from_string(citation_string)

    assert_equal 1, citations.length, 'Expected one citation'
    assert_equal 'The Art of Happiness', citations[0][:metadata][:title], 'Expected title to match'
    assert_equal 'Dalai Lama', citations[0][:metadata][:author], 'Expected author to match'
    assert_equal '', citations[0][:metadata][:publisher], 'Expected publisher to be empty'
    assert_equal '1998', citations[0][:metadata][:publication_date], 'Expected publication date to match'
    assert_equal '', citations[0][:metadata][:edition], 'Expected edition to be empty'
  end

  test 'citations_from_string handles empty string' do
    citation_string = ''
    parsed_metadata = []

    AnyStyle.stubs(:parse).with(citation_string).returns(parsed_metadata)

    citations = @service.citations_from_string(citation_string)

    assert_empty citations, 'Expected no citations for empty string'
  end

  # create_citations_from_string tests
  test 'create_citations_from_string creates citations successfully' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    citation_string = "Dalai Lama. (1998). The Art of Happiness. Riverhead Books."
    parsed_metadata = [
      {
        author: [{ family: 'Dalai Lama' }],
        title: ['The Art of Happiness'],
        date: ['1998'],
        publisher: ['Riverhead Books']
      }
    ]

    AnyStyle.stubs(:parse).with(citation_string).returns(parsed_metadata)

    success_response = {
      body: {
        id: 'CIT-001',
        type: { value: 'BK' },
        metadata: { title: 'The Art of Happiness', author: 'Dalai Lama' }
      }.to_json,
      code: 201
    }

    stubbed_response = stub(success?: true, body: success_response[:body], code: success_response[:code])
    AlmaCourseService.stubs(:post).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: anything
    ).returns(stubbed_response)

    result = @service.create_citations_from_string(course_id, reading_list_id, citation_string)

    assert_equal 1, result.length, 'Expected one citation to be created'
    assert result[0][:success], 'Expected success to be true'
    assert_equal 'CIT-001', result[0][:data][:id], 'Expected citation ID to match'
    assert_equal 'The Art of Happiness', result[0][:data][:metadata][:title], 'Expected citation title to match'
  end

  test 'create_citations_from_string handles API error for one citation' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    citation_string = "Dalai Lama. (1998). The Art of Happiness. Riverhead Books."
    parsed_metadata = [
      {
        author: [{ family: 'Dalai Lama' }],
        title: ['The Art of Happiness'],
        date: ['1998'],
        publisher: ['Riverhead Books']
      }
    ]

    AnyStyle.stubs(:parse).with(citation_string).returns(parsed_metadata)

    error_response = {
      body: { error: 'Invalid citation data' }.to_json,
      code: 400,
      message: 'Bad Request'
    }

    stubbed_response = stub(success?: false, body: error_response[:body], code: error_response[:code], message: error_response[:message])
    AlmaCourseService.stubs(:post).with(
      "/courses/#{course_id}/reading-lists/#{reading_list_id}/citations?apikey=test-api-key",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: anything
    ).returns(stubbed_response)

    result = @service.create_citations_from_string(course_id, reading_list_id, citation_string)

    assert_equal 1, result.length, 'Expected one citation to be processed'
    assert_not result[0][:success], 'Expected success to be false'
    assert_equal 400, result[0][:error], 'Expected error code to be 400'
    assert_equal 'Bad Request', result[0][:message], 'Expected error message to match'
    assert_equal 'Invalid citation data', result[0][:details][:error], 'Expected error details to match'
  end

  test 'create_citations_from_string handles empty string' do
    course_id = '12345'
    reading_list_id = 'RL-001'
    citation_string = ''
    parsed_metadata = []

    AnyStyle.stubs(:parse).with(citation_string).returns(parsed_metadata)

    result = @service.create_citations_from_string(course_id, reading_list_id, citation_string)

    assert_empty result, 'Expected no citations to be created for empty string'
  end
end